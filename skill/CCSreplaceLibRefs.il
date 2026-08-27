
;; ============================================================================
;; CCSreplaceLibRefs
;;
;; PURPOSE
;; Walks a hard-coded set of libraries, opens only the specified
;; view types (e.g. "layout", "schematic") for each cell in those
;; libraries (NOT descending into instances' own hierarchy), and
;; reassigns the master library for any instHeader whose current
;; library matches an entry in libMap.
;;
;; libMap  : table, oldLibName -> newLibName (built with makeTable)
;; srcLibs : list of library name strings to scan
;; viewList: list of view name strings to process, e.g. list("layout")
;; dryRun  : t = report only, no changes saved
;;           nil = actually reassign + dbSave
;;
;; NOTES / UNVERIFIED ITEMS
;;  1. dbOpenCellViewByType(...) mode string "a" is used to open for
;;     edit without erasing the view. Testing so far has not shown
;;     data loss, but keep an eye on this on new library types.
;;  2. Can't directly assign `instHeader~>libName = newLib`. Must use
;;     `dbSetInstHeaderMasterName(instHeader newLib nil nil)`.
;;  3. Pcell instances are NOT special-cased -- they'll go through
;;     the same libName reassignment as any other instHeader. Ignored
;;     for now per direction; flagging in case a pcell shows up in a
;;     scanned library.
;;  4. dbSetInstHeaderMasterName fails if the target library does not
;;     yet exist (confirmed by testing). A preflight check (below)
;;     now verifies every target library in libMap resolves via
;;     ddGetObj before any cellview is touched, so this should
;;     surface as a clear upfront error instead of a mid-run failure.
;;  5. On a successful call, dbSetInstHeaderMasterName moves the
;;     instHeader to a new master bucket and frees the original
;;     handle (confirmed by testing -- "purged/freed object" and nil
;;     fields if you read instHeader~>... afterward). Any display
;;     values needed for logging must be captured into locals BEFORE
;;     calling dbSetInstHeaderMasterName, never read from instHeader
;;     after.
;;
;; USAGE
;; - Rename to new library in `cds.lib`. Modify `srcLibs` for the new
;;   library name to scan. The new (target) libraries must already
;;   exist in `cds.lib` -- the preflight check below will abort an
;;   execute run (not a dry run) if any target library is missing.
;; - Modify `libMap` table for *old libName* to *new libName*.
;; - Both a dry run and an execute run can be left uncommented in
;;   CCSRunReplaceLibRefs -- dry run opens read-only and holds no
;;   write lock, so it's safe to run immediately before the real one.
;;
;;
;; ============================================================================

;; HISTORY
;; 2026/08/24 - dpeng
;; - Initial creation based on Claude and Cadence support site.
;; - Use `dbSetInstHeaderMasterName` to set the library name. All examples uses
;;   instHeaders from opened cells instead of `inst`.
;;
;; 2026/08/25 - dpeng
;; - Adding USAGE section.
;;
;; 2026/08/26 - dpeng
;; - Added preflight check: verifies every target (new) library in libMap
;;   resolves via ddGetObj before any cellview is touched; aborts execute
;;   runs (not dry runs) if any are missing, with a full list printed.
;; - Wrapped dbSetInstHeaderMasterName in errset so one failed instHeader
;;   (e.g. race condition on a library) warns and continues instead of
;;   aborting the whole run; added a separate totalFailed counter.
;; - Fixed *Error* fprintf/sprintf nil argument on execute runs: the
;;   success-path printf was reading instHeader~>cellName/libName AFTER
;;   dbSetInstHeaderMasterName succeeded, but that call frees the
;;   instHeader handle on success ("purged/freed object"). Now captures
;;   cellLabel/oldLibLabel into locals before the call and prints those
;;   instead of touching instHeader afterward.
;; - Change indentation from 2 -> 4 spaces.
;;
;; ============================================================================

; Create a unique list
procedure(CCSuniqueList(lst)
    let((seen result)
        seen = makeTable("CCSuniqueSeen" nil)
        result = nil
        foreach(item lst
            unless(seen[item]
                seen[item] = t
                result = cons(item result)
            )
        )
        reverse(result)
    )
) ; END: CCSuniqueList


; Replaces the old library with new library names.
procedure(CCSreplaceLibRefs(libMap srcLibs viewList @optional (dryRun t))
    let((libObj cellNames cv newLib totalChanged totalOpened totalSkipped
              totalFailed uniqSrcLibs uniqViews mode missingLibs shouldRun)

        totalChanged = 0
        totalOpened  = 0
        totalSkipped = 0
        totalFailed  = 0
        shouldRun    = t

        uniqSrcLibs = CCSuniqueList(srcLibs)
        uniqViews   = CCSuniqueList(viewList)

        mode = if(dryRun then "r" else "a")

        printf("\n=== CCSreplaceLibRefs starting (dryRun=%L) ===\n" dryRun)

        ;; ------------------------------------------------------------------
        ;; Preflight: verify every target ("new") library in libMap actually
        ;; resolves before touching any cellviews. A missing target library
        ;; is the confirmed cause of dbSetInstHeaderMasterName failing.
        ;; ------------------------------------------------------------------
        missingLibs = nil
        foreach(oldLib libMap->?
            newLib = libMap[oldLib]
            unless(ddGetObj(newLib)
                missingLibs = cons(newLib missingLibs)
            )
        )
        missingLibs = CCSuniqueList(missingLibs)

        when(missingLibs
            printf("*ERROR* The following target libraries in libMap do not resolve (check cds.lib):\n")
            foreach(m missingLibs
                printf("    %s\n" m)
            )
            unless(dryRun
                printf("*ERROR* Aborting execute run -- fix cds.lib before running again.\n\n")
                shouldRun = nil
            )
        )

        ;; ------------------------------------------------------------------
        ;; Main pass
        ;; ------------------------------------------------------------------
        when(shouldRun
            foreach(lib uniqSrcLibs
                libObj = ddGetObj(lib)
                if(libObj then
                    cellNames = libObj~>cells~>name

                    foreach(cellName cellNames
                        foreach(viewName uniqViews

                            cv = dbOpenCellViewByType(lib cellName viewName "" mode)

                            if(cv then
                                totalOpened = totalOpened + 1

                                let((instChangedThisCV setResult oldLibLabel cellLabel)
                                    instChangedThisCV = 0

                                    ; Going through each instHeader in the cellview
                                    foreach(instHeader cv~>instHeaders
                                        newLib = libMap[instHeader~>libName]
                                        when(newLib
                                            ;; Capture display values BEFORE calling
                                            ;; dbSetInstHeaderMasterName. On success, that
                                            ;; call moves the instHeader to a new master
                                            ;; bucket and frees this handle -- reading
                                            ;; instHeader~>... afterward returns nil and
                                            ;; throws a "purged/freed object" warning.
                                            oldLibLabel = instHeader~>libName
                                            cellLabel   = instHeader~>cellName

                                            if(dryRun then
                                                printf("  %s %s %s : instHeader %s  %s -> %s (dry-run)\n"
                                                    lib cellName viewName
                                                    cellLabel oldLibLabel newLib)
                                                instChangedThisCV = instChangedThisCV + 1
                                                totalChanged = totalChanged + 1
                                            else

                                                ; errset to capture in case of error for setting name.
                                                ; `dbSetInstHeaderMasterName` is actual function that changes names.
                                                setResult = errset(dbSetInstHeaderMasterName(instHeader newLib nil nil))
                                                if(setResult then
                                                    printf("  %s %s %s : instHeader %s  %s -> %s\n"
                                                        lib cellName viewName
                                                        cellLabel oldLibLabel newLib)
                                                    instChangedThisCV = instChangedThisCV + 1
                                                    totalChanged = totalChanged + 1
                                                else
                                                    warn("Could not set master to '%s' for instHeader (was '%s') in %s %s %s\n"
                                                        newLib oldLibLabel lib cellName viewName)
                                                    totalFailed = totalFailed + 1
                                                )
                                            )
                                        )
                                    ) ; END: foreach: cv~>instHeaders

                                    if(and(!dryRun instChangedThisCV > 0) then
                                        dbSave(cv)
                                    )
                                ) ; END: let

                                ; Reopen cell as "read only" to for getting rid of *.cdslck file.
                                dbReopen(cv "r")
                                dbClose(cv)

                            else
                                ;; view doesn't exist, or checked out/locked elsewhere --
                                ;; warn and skip.
                                totalSkipped = totalSkipped + 1
                                warn("Could not open %s %s %s -- skipping (missing view or locked)\n"
                                          lib cellName viewName)
                            ) ; END: if: cv
                        ) ; END: foreach: view type
                    ) ; END: foreach: cell
                else
                    warn("Library '%s' not found in srcLibs -- skipping\n" lib)
                )
            )
        )

        printf("=== Done: %d cellviews opened, %d instHeaders %s, %d failed, %d cellviews skipped ===\n\n"
                      totalOpened totalChanged
                      if(dryRun "would change" "changed")
                      totalFailed totalSkipped)

        list(?opened totalOpened ?changed totalChanged ?failed totalFailed
                  ?skipped totalSkipped ?missingLibs missingLibs)
    ) ; END: let: Main function
) ; END: CCSreplaceLibRefs


procedure(CCSRunReplaceLibRefs()
    let((libMap srcLibs viewList)

        ; USER: Edit for *old name* vs *new name*
        libMap = makeTable("libMap" nil)
        libMap["cgnd"] = "cgnd_revc"
        libMap["vbb"] = "vbb_revc"
        libMap["vbbsa"] = "vbbsa_revc"
        libMap["vbleq_0"] = "vbleq_0_revc"
        libMap["vbleq_1"] = "vbleq_1_revc"
        libMap["vcc"] = "vcc_revc"
        libMap["vccckt"] = "vccckt_revc"
        libMap["vccdll"] = "vccdll_revc"
        libMap["vccdllc"] = "vccdllc_revc"
        libMap["vcsa"] = "vcsa_revc"
        libMap["vdd"] = "vdd_revc"
        libMap["vdda"] = "vdda_revc"
        libMap["vddl"] = "vddl_revc"
        libMap["vddq"] = "vddq_revc"
        libMap["vdin"] = "vdin_revc"
        libMap["vdin_dq"] = "vdin_dq_revc"
        libMap["vkk"] = "vkk_revc"
        libMap["vod"] = "vod_revc"
        libMap["vpl"] = "vpl_revc"
        libMap["vpp"] = "vpp_revc"
        libMap["vsin"] = "vsin_revc"
        libMap["vsin_dq"] = "vsin_dq_revc"
        libMap["vss"] = "vss_revc"
        libMap["vssckt"] = "vssckt_revc"
        libMap["vssdll"] = "vssdll_revc"
        libMap["vssdllc"] = "vssdllc_revc"
        libMap["vssl"] = "vssl_revc"
        libMap["xvdd"] = "xvdd_revc"
        libMap["xvddl"] = "xvddl_revc"
        libMap["xvddq"] = "xvddq_revc"
        libMap["xvss"] = "xvss_revc"
        libMap["xvssl"] = "xvssl_revc"

        ; USER: Edit for libraries to look at.
        ;srcLibs  = list( "vbb_revc" )   ;; libraries to scan cells in
        ;srcLibs  = list( "vbbsa_revc" )   ;; libraries to scan cells in
        ;srcLibs  = list( "vbleq_0_revc" )   ;; libraries to scan cells in
        ;srcLibs  = list( "vccckt_revc" )   ;; libraries to scan cells in
        srcLibs  = list( "vccdll_revc" )   ;; libraries to scan cells in
        ;srcLibs  = list(
        ;	"cgnd_revc"
        ;	"vbb_revc" "vbbsa_revc" "vbleq_0_revc" "vbleq_1_revc"
        ;	"vcc_revc" "vccckt_revc" "vccdll_revc" "vccdllc_revc"
        ;	"vcsa_revc"
        ;	"vdd_revc" "vdda_revc" "vddl_revc" "vddq_revc" "vdin_revc" "vdin_dq_revc"
        ;	"vkk_revc" "vod_revc" "vpl_revc" "vpp_revc" "vsin_revc"
        ;	"vsin_dq_revc" "vss_revc" "vssckt_revc" "vssdll_revc" "vssdllc_revc" "vssl_revc" "xvdd_revc"
        ;	"xvddl_revc" "xvddq_revc"
        ;	"xvss_revc" "xvssl_revc"
        ;)   ;; libraries to scan cells in


        ; USER: Edit for specific cell view type.
        viewList = list("layout")
        ;viewList = list("schematic")
        ;viewList = list("layout" "schematic")

        ; USER: dry run and execute can both run in the same pass --
        ; dry run opens read-only and holds no write lock.
        ;; Step 1: dry run, just review the printed report
        CCSreplaceLibRefs(libMap srcLibs viewList t)

        ;; Step 2: once you're satisfied, execute for real
        CCSreplaceLibRefs(libMap srcLibs viewList nil)
    ) ; let
) ; procedure CCSRunReplaceLibRefs: Selecting which


procedure(lp()
    prog(()
        ;geDiscardEdits()
        load("/user/dpeng/GIT/work/skill/CCSreplaceLibRefs.il")
        CCSRunReplaceLibRefs()
    )
) ; END: procedure: lp
