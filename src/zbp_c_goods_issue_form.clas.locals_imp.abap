    CLASS lhc_ZC_Goods_Issue_Form DEFINITION INHERITING FROM cl_abap_behavior_handler.
      PRIVATE SECTION.

        METHODS get_instance_features FOR INSTANCE FEATURES
          IMPORTING keys REQUEST requested_features FOR ZC_Goods_Issue_Form RESULT result.

        METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
          IMPORTING keys REQUEST requested_authorizations FOR ZC_Goods_Issue_Form RESULT result.

        METHODS read FOR READ
          IMPORTING keys FOR READ ZC_Goods_Issue_Form RESULT result.

        METHODS lock FOR LOCK
          IMPORTING keys FOR LOCK ZC_Goods_Issue_Form.

        METHODS btnPrintPDF FOR MODIFY
          IMPORTING keys FOR ACTION ZC_Goods_Issue_Form~btnPrintPDF RESULT result.

    ENDCLASS.

    CLASS lhc_ZC_Goods_Issue_Form IMPLEMENTATION.

      METHOD get_instance_features.
      ENDMETHOD.

      METHOD get_instance_authorizations.
      ENDMETHOD.

      METHOD read.
      ENDMETHOD.

      METHOD lock.
      ENDMETHOD.

      METHOD btnPrintPDF.
        zcl_pdf_reportt=>btnPrintPDF_PXK(
      EXPORTING
        KEYS     = KEYS
*      IMPORTING
*        O_PDF    = LV_FILE_CONTENT
      CHANGING
        RESULT   = result
        MAPPED   = MAPPED
        FAILED   = FAILED
        REPORTED = REPORTED
         ).
      ENDMETHOD.

    ENDCLASS.

    CLASS lsc_ZC_GOODS_ISSUE_FORM DEFINITION INHERITING FROM cl_abap_behavior_saver.
      PROTECTED SECTION.

        METHODS finalize REDEFINITION.

        METHODS check_before_save REDEFINITION.

        METHODS save REDEFINITION.

        METHODS cleanup REDEFINITION.

        METHODS cleanup_finalize REDEFINITION.

    ENDCLASS.

    CLASS lsc_ZC_GOODS_ISSUE_FORM IMPLEMENTATION.

      METHOD finalize.
      ENDMETHOD.

      METHOD check_before_save.
      ENDMETHOD.

      METHOD save.
      ENDMETHOD.

      METHOD cleanup.
      ENDMETHOD.

      METHOD cleanup_finalize.
      ENDMETHOD.

    ENDCLASS.
