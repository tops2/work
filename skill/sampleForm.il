; ===========================================================================
; sampleForm.il
;
; PURPOSE
; Tutorial template: a SKILL GUI form with 4 field types, demonstrating how
; to build a form and pull values out of it in the OK callback.
;
;
; USAGE
; Load in CIW with:  load("sampleForm.il")
; Run with:           myFormShow()
;
; ===========================================================================

; HISTORY
; 2026/09/03 - dpeng
; - Initial creation using Claude as reference.
;
;
; ===========================================================================

; Global variable that will hold the extracted values after the user clicks OK.
; Using a global here (rather than just printing) so you can inspect it from
; the CIW afterwards, e.g. typing `myFormResults` at the prompt.
myFormResults = nil

; ===========================================================================
; Callback function: fires when the user clicks OK on the form.
; `form` is passed in automatically by hiCreateAppForm's callback mechanism;
; each field is accessed as form->fieldSymbolicName->value
; ===========================================================================
procedure( myFormCallback(form)
    let( (theString theBool theFruit theCruise)

        ; --- Field 1: string field -------------------------------------------
        theString = form->myStringField->value

        ; --- Field 2: boolean checkbox -----------------------------------------
        ; hiCreateBooleanButton fields return t or nil
        theBool = form->myBoolField->value

        ; --- Field 3: "dropdown" (cyclic field) ---------------------------------
        ; FLAGGED: using hiCreateCyclicField here, NOT a confirmed true pulldown
        ; widget -- see notes above/below. ->value returns the selected string.
        theFruit = form->myFruitField->value

        ; --- Field 4: radio field -----------------------------------------------
        ; hiCreateRadioField ->value returns the selected string (buttonText entry)
        theCruise = form->myCruiseField->value

        ; Store everything in one list so it's easy to inspect/reuse later.
        myFormResults = list(
            nil ; placeholder tag, replace with 'results if you want a tagged list
            "string"  theString
            "boolean" theBool
            "fruit"   theFruit
            "cruise"  theCruise
        )

        ; Print to CIW for immediate visual feedback while learning.
        printf("---- Form values ----\n")
        printf("String field : %s\n" theString)
        printf("Boolean field: %L\n" theBool)
        printf("Fruit field  : %s\n" theFruit)
        printf("Cruise field : %s\n" theCruise)
        printf("----------------------\n")
        printf("Also stored in global variable: myFormResults\n")
    ) ; let
) ; procedure myFormCallback

; ===========================================================================
; Form definition + display function
; ===========================================================================
procedure( myFormShow()
    let( (form)

        ; ---- Field 1: string field --------------------------------------------
        myStringField = hiCreateStringField(
            ?name          'myStringField
            ?prompt        "Type a string"
            ?value         ""          ; default value
            ?editable      t
        )

        ; ---- Field 2: boolean checkbox -----------------------------------------
        myBoolField = hiCreateBooleanButton(
            ?name          'myBoolField
            ?buttonText    "Enable option"
            ?value         nil         ; default False
        )

        ; ---- Field 3: "dropdown" via cyclic field -------------------------------
        ; FLAGGED AS UNCERTAIN: hiCreateCyclicField is a confirmed-real function
        ; that cycles through choices on click. If you find a true pulldown/combo
        ; constructor on your Virtuoso version, swap this block out -- the
        ; ->value extraction in the callback above will still work the same way.
        myFruitField = hiCreateCyclicField(
            ?name          'myFruitField
            ?prompt        "Choose a fruit"
            ?choices       list("apple" "grape" "pear")
            ?value         "apple"     ; default selection
        )

        ; ---- Field 4: radio selection -------------------------------------------
        myCruiseField = hiCreateRadioField(
            ?name          'myCruiseField
            ?prompt        "Choose a cruise line"
            ?choices list("Disney Cruise" "Royal Caribbean" "other")
            ?value         "Disney Cruise"  ; default selection
        )

        ; ---- Assemble the form ---------------------------------------------------
        form = hiCreateAppForm(
            ?name          'myForm
            ?formTitle     "Sample Learning Form"
            ?fields        list(
                myStringField
                myBoolField
                myFruitField
                myCruiseField
            )
            ?buttonLayout  'OKCancel   ; standard OK/Cancel button set
            ?callback      "myFormCallback(myForm)"
        )

        hiDisplayForm(form)
    ) ; let
) ; procedure myFormShow


; Reload the script and run the main function.
procedure(lp()
    prog(()
        load("/user/dpeng/GIT/work/skill/sampleForm.il")
        myFormShow()
    )
) ; END: procedure: lp
