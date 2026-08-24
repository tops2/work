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
;;  2. inst~>libName = newLib -- I cannot confirm from documentation
;;     that this cleanly re-binds the instance master vs. just
;;     changing a display string with a stale cached pointer. Test
;;     this specifically: reassign, save, close, reopen, and check
;;     the instance is genuinely "broken" (referencing new lib name)
;;     rather than corrupted.
;;  3. Pcell instances are NOT special-cased -- they'll go through
;;     the same libName reassignment as any other instance. Per your
;;     note, this is being ignored for now, but flagging it here so
;;     it's not forgotten if a pcell shows up in scanned libraries.
;; ============================================================================

;; HISTORY
;; 2026/08/24 - dpeng
;; - Initial creation based on Claude and Cadence support site.
;;
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

                ;foreach(inst cv~>instances
                foreach(inst cv~>instHeaders
                  newLib = libMap[inst~>libName]
                  when(newLib
                    printf("  %s %s %s : inst %s  %s -> %s%s\n"
                           lib cellName viewName
                           inst~>name inst~>libName newLib
                           if(dryRun " (dry-run)" ""))
                    unless(dryRun
                      inst~>libName = newLib
                      ;; NOTE: Need to use either:
                      ;; dbSetInstHeaderMasterName
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
		;; ... up to your ~32-33 entries

		srcLibs  = list( "vbb" )   ;; libraries to scan cells in
		;srcLibs  = list( "cgnd" "vbb" "vbbsa" "vbleq_0" "vbleq_1" "vcc" )   ;; libraries to scan cells in
		viewList = list("layout")                ;; or list("layout" "schematic")

		;; Step 1: dry run, just review the printed report
		;CCSreplaceLibRefs(libMap srcLibs viewList t)

		;; Step 2: once you're satisfied, execute for real
		CCSreplaceLibRefs(libMap srcLibs viewList nil)
    ) ; let
) ; procedure CCSRunReplaceLibRefs


procedure(lp()
    prog(()
        ;geDiscardEdits()
        load("/user/dpeng/GIT/work/skill/CCSreplaceLibRefs.il")
        CCSRunReplaceLibRefs()
    )
)
