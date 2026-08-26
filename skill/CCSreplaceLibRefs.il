;; ============================================================================
;; CCSreplaceLibRefs
;;
;; PURPOSE
;; Walks a hard-coded set of libraries, opens only the specified
;; view types (e.g. "layout", "schematic") for each cell in those
;; libraries (NOT descending into instances' own hierarchy), and
;; reassigns inst~>libName for any instance whose current library
;; matches an entry in libMap.
;;
;; libMap  : table, oldLibName -> newLibName (built with makeTable)
;; srcLibs : list of library name strings to scan
;; viewList: list of view name strings to process, e.g. list("layout")
;; dryRun  : t = report only, no changes saved
;;           nil = actually reassign + dbSave
;;
;; NOTES / UNVERIFIED ITEMS (please test on a sandbox lib first):
;;  1. dbOpenCellViewByType(...) mode string "a" is my best
;;     understanding for "open existing cellview for edit without
;;     erasing it." Please confirm this doesn't blank the view.
;;  2. inst~>libName = newLib
;;     Can't directly assign library names. Need to use
;;     `dbSetInstHeaderMasterName` and set to valid library name.
;;  3. Pcell instances are NOT special-cased -- they'll go through
;;     the same libName reassignment as any other instance. Per your
;;     note, this is being ignored for now, but flagging it here so
;;     it's not forgotten if a pcell shows up in scanned libraries.
;;
;; USAGE
;; - Rename to new library in `cds.lib`. Modify `srcLibs` for the new library
;;   name to scan. Need to have new library to exist for SKILL to work.
;; - Modify `libMap` table for *old libName* to *new libName*
;; - Hard code to do a dry run first or actual renaming.
;;
;; TODO
;; - Need to check about closing cell. Currently still shows user checking out
;;   cellview.
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
;; ============================================================================


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
)

procedure(CCSreplaceLibRefs(libMap srcLibs viewList @optional (dryRun t))
  let((libObj cellNames cv newLib totalChanged totalOpened totalSkipped
       uniqSrcLibs uniqViews mode)

    totalChanged = 0
    totalOpened  = 0
    totalSkipped = 0

    uniqSrcLibs = CCSuniqueList(srcLibs)
    uniqViews   = CCSuniqueList(viewList)

    mode = if(dryRun then "r" else "a")

    printf("\n=== CCSreplaceLibRefs starting (dryRun=%L) ===\n" dryRun)

    foreach(lib uniqSrcLibs
      libObj = ddGetObj(lib)
      if(libObj then
        cellNames = libObj~>cells~>name

        foreach(cellName cellNames
          foreach(viewName uniqViews

            cv = dbOpenCellViewByType(lib cellName viewName "" mode)

            if(cv then
              totalOpened = totalOpened + 1
              let((instChangedThisCV)
                instChangedThisCV = 0

                ; Going through each instance in cellview
                foreach(instHeader cv~>instHeaders
                  newLib = libMap[instHeader~>libName]
                  when(newLib
                    printf("  %s %s %s : instHeader %s  %s -> %s%s\n"
                           lib cellName viewName
                           instHeader~>cellName instHeader~>libName newLib
                           if(dryRun " (dry-run)" ""))
                    unless(dryRun
                      ;;inst~>libName = newLib
                      ;; NOTE: Can't directly assign something like:
                      ;; instHeader~>libName = newLib
                      ;; NOTE: Only successful rename if library exists.
                      dbSetInstHeaderMasterName(
                        instHeader
                        newLib
                        nil
                        nil
                      )
                    )
                    instChangedThisCV = instChangedThisCV + 1
                    totalChanged = totalChanged + 1
                  )
                )

                if(and(!dryRun instChangedThisCV > 0) then
                  dbSave(cv)
                )
              )
              dbClose(cv)

            else
              ;; case 3 (view doesn't exist) and case 4 (locked/
              ;; checked out by someone else) both land here --
              ;; warn and skip, per your call.
              totalSkipped = totalSkipped + 1
              warn("Could not open %s %s %s -- skipping (missing view or locked)\n"
                   lib cellName viewName)
            )
          )
        )
      else
        warn("Library '%s' not found in srcLibs -- skipping\n" lib)
      )
    )

    printf("=== Done: %d cellviews opened, %d instances %s, %d cellviews skipped ===\n\n"
           totalOpened totalChanged
           if(dryRun "would change" "changed")
           totalSkipped)

    list(?opened totalOpened ?changed totalChanged ?skipped totalSkipped)
  )
)


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
		srcLibs  = list( "vbleq_1_revc" "vbleq_1_revc" )   ;; libraries to scan cells in
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
		;viewList = list("layout")
		;viewList = list("schematic")
		viewList = list("layout" "schematic" "symbol")

		; USER: Edit for "dry run" vs execute for real.
		;; Step 1: dry run, just review the printed report
		CCSreplaceLibRefs(libMap srcLibs viewList t)

		;; Step 2: once you're satisfied, execute for real
		;CCSreplaceLibRefs(libMap srcLibs viewList nil)
    ) ; let
) ; procedure CCSRunReplaceLibRefs


procedure(lp()
    prog(()
        ;geDiscardEdits()
        load("/user/dpeng/GIT/work/skill/CCSreplaceLibRefs.il")
        CCSRunReplaceLibRefs()
    )
)
