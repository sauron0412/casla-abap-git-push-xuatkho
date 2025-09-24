CLASS zcl_goods_issue_form_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

         TYPES: BEGIN OF ty_item_json_1,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE string,
             high   TYPE string,
           END OF ty_item_json_1,

           tt_ranges TYPE TABLE OF ty_item_json_1.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_item_json,
             numberoforder         TYPE string,
             materialnumber        TYPE matnr,
             batchnumber           TYPE charg_d,
             materialdescription   TYPE maktx,
             unitofmeasurementtext TYPE msehl,
             salesordernumber      TYPE vbeln_va,
             salesorderitem        TYPE posnr,
             quantityinunitofentry TYPE erfmg,
             purchaseorderquantity TYPE menge_d,
             amountinlocalcurrency TYPE wrbtr,
             unitprice             TYPE wrbtr,
             currencykey           TYPE waers,
           END OF ty_item_json.
    TYPES tt_item_json TYPE STANDARD TABLE OF ty_item_json WITH EMPTY KEY.

    METHODS convert_line_items_to_json
      IMPORTING it_line_items  TYPE tt_item_json
      RETURNING VALUE(rv_json) TYPE string.

ENDCLASS.



CLASS ZCL_GOODS_ISSUE_FORM_QUERY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE STANDARD TABLE OF zc_goods_receipt_form WITH EMPTY KEY.

    TRY.
        DATA(lo_filter) = io_request->get_filter( ).
        DATA(lt_filters) = lo_filter->get_as_ranges( ).
        IF lo_filter IS BOUND.
          DATA(lr_year)  = lt_filters[ name = 'FISCALYEAR' ]-range.
          DATA(lr_mblnr) = lt_filters[ name = 'MATERIALDOCUMENT' ]-range.
        ENDIF.
      CATCH cx_rap_query_filter_no_range INTO DATA(lx_no_range).
        RETURN.
    ENDTRY.

    " Get comprehensive data with all required joins
    SELECT FROM i_materialdocumentitem_2 AS a
      INNER JOIN i_goodsmovementtype AS b
         ON a~goodsmovementtype = b~goodsmovementtype
      LEFT OUTER JOIN i_materialdocumentheader_2 AS c
         ON a~materialdocument = c~materialdocument
        AND a~materialdocumentyear = c~materialdocumentyear
      LEFT OUTER JOIN i_productdescription AS d
         ON a~material = d~product
        AND d~language = @sy-langu
      LEFT OUTER JOIN i_unitofmeasuretext AS e
         ON a~entryunit = e~unitofmeasure
        AND e~language = @sy-langu
      LEFT OUTER JOIN i_customer AS f
         ON a~customer = f~customer
      LEFT OUTER JOIN i_plant AS g
         ON a~plant = g~plant
      LEFT OUTER JOIN i_purchaseorderitemapi01 AS h
         ON a~purchaseorder = h~purchaseorder
         AND a~purchaseorderitem = h~purchaseorderitem
      LEFT OUTER JOIN i_reservationdocumentitem AS i
          ON a~reservation = i~reservation
            AND a~reservationitem = i~reservationitem
      LEFT OUTER JOIN i_salesdocumentitem AS j
          ON a~specialstockidfgsalesorder = j~salesdocument
            AND a~specialstockidfgsalesorderitem = j~salesdocumentitem
      LEFT OUTER JOIN i_manufacturingorderitem AS k
          ON a~orderid = k~manufacturingorder
            AND a~orderitem = k~manufacturingorderitem
      LEFT OUTER JOIN i_deliverydocumentitem AS l
          ON a~deliverydocument = l~deliverydocument
            AND a~deliverydocumentitem = l~deliverydocumentitem
      FIELDS a~materialdocument,
             a~materialdocumentyear,
             a~materialdocumentitem,
             a~material,
             a~batch,
             a~specialstockidfgsalesorder,
             a~specialstockidfgsalesorderitem,
             a~quantityinentryunit,
             a~quantityinbaseunit,
             h~orderquantity,
             i~resvnitmrequiredqtyinentryunit,
             j~orderquantity AS so_quantity,
             k~mfgorderitemplannedtotalqty,
             l~actualdeliveryquantity,
             a~totalgoodsmvtamtincccrcy,
             a~companycodecurrency,
             a~plant,
             a~companycode,
             a~purchaseorder,
             a~purchaseorderitem,
             a~reservation,
             a~reservationitem,
             a~orderid,
             a~orderitem,
             a~deliverydocument,
             a~deliverydocumentitem,
             c~documentdate,
             c~postingdate,
             c~materialdocumentheadertext,
             d~productdescription AS materialname,
             e~unitofmeasurelongname,
             f~customerfullname AS customername,
             g~plantname
      WHERE a~materialdocument IN @lr_mblnr
        AND a~isautomaticallycreated <> 'X'
        AND a~materialdocumentyear IN @lr_year
        AND b~debitcreditcode = 'H'
        AND b~isreversalmovementtype = ''
        AND a~reversedmaterialdocument = ''
        AND NOT EXISTS ( SELECT reversedmaterialdocument FROM i_materialdocumentitem_2 AS x
              WHERE a~materialdocument = x~reversedmaterialdocument
              AND a~materialdocumentyear = x~reversedmaterialdocumentyear
              AND a~materialdocumentitem = x~reversedmaterialdocumentitem )
    INTO TABLE @DATA(lt_data).

    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_data BY materialdocument materialdocumentyear materialdocumentitem.
    DATA: lv_no TYPE int4 VALUE 0.

    " Process grouped data by material document
    LOOP AT lt_data INTO DATA(lg_data)
    GROUP BY ( materialdocument = lg_data-materialdocument
               materialdocumentyear = lg_data-materialdocumentyear )
    ASSIGNING FIELD-SYMBOL(<group>).

      DATA: lt_items_json TYPE tt_item_json.
      CLEAR lt_items_json.

      " Build line items for JSON
      CLEAR lv_no.
      LOOP AT GROUP <group> INTO DATA(ls_item).
        lv_no += 1.
        IF lv_no = 1.
          " Store header data from first item
          DATA(ls_result) = VALUE zc_goods_receipt_form(
             materialdocument     = ls_item-materialdocument
             fiscalyear           = ls_item-materialdocumentyear
             companycode          = ls_item-companycode
             purchaseordernumber  = ls_item-purchaseorder
             numberofreservation  = ls_item-reservation
             materialdocumentdate = ls_item-documentdate
             vendorname           = ls_item-customername
             plantname            = ls_item-plantname
             documentheadertext   = ls_item-materialdocumentheadertext
             postingdate          = ls_item-postingdate  ).
        ENDIF.
        " Prepare item data for JSON
        DATA(ls_item_json) = VALUE ty_item_json(
          numberoforder         = |{ lv_no ZERO = NO }|
          materialnumber        = |{ ls_item-material ALPHA = OUT }|
          batchnumber           = |{ ls_item-batch ALPHA = OUT }|
          materialdescription   = ls_item-materialname
          unitofmeasurementtext = ls_item-unitofmeasurelongname
          salesordernumber      = ls_item-specialstockidfgsalesorder
          salesorderitem        = ls_item-specialstockidfgsalesorderitem
          quantityinunitofentry = ls_item-quantityinentryunit
          purchaseorderquantity = COND #( WHEN ls_item-purchaseorder IS NOT INITIAL AND ls_item-purchaseorderitem IS NOT INITIAL
                                          THEN ls_item-orderquantity
                                          WHEN ls_item-reservation IS NOT INITIAL AND ls_item-reservationitem IS NOT INITIAL
                                          THEN ls_item-resvnitmrequiredqtyinentryunit
                                          WHEN ls_item-specialstockidfgsalesorder IS NOT INITIAL AND ls_item-specialstockidfgsalesorderitem IS NOT INITIAL
                                          THEN ls_item-so_quantity
                                          WHEN ls_item-orderid IS NOT INITIAL AND ls_item-orderitem IS NOT INITIAL
                                          THEN ls_item-mfgorderitemplannedtotalqty
                                          WHEN ls_item-deliverydocument IS NOT INITIAL AND ls_item-deliverydocumentitem IS NOT INITIAL
                                          THEN ls_item-actualdeliveryquantity
                                          ELSE 0 )
          currencykey           = ls_item-companycodecurrency
          amountinlocalcurrency = COND #( WHEN ls_item-companycodecurrency = 'VND'
                                          THEN ls_item-totalgoodsmvtamtincccrcy * 100
                                          ELSE ls_item-totalgoodsmvtamtincccrcy )
          unitprice             = COND #( WHEN ls_item-quantityinentryunit <> 0 AND ls_item-companycodecurrency <> 'VND'
                                         THEN ls_item-totalgoodsmvtamtincccrcy / ls_item-quantityinentryunit
                                         WHEN ls_item-quantityinentryunit <> 0 AND ls_item-companycodecurrency = 'VND'
                                         THEN ls_item-totalgoodsmvtamtincccrcy / ls_item-quantityinentryunit * 100
                                         ELSE 0 )
           ).
        APPEND ls_item_json TO lt_items_json.
        CLEAR ls_item_json.
      ENDLOOP.

      " Convert to JSON
      DATA(lv_json_string) = convert_line_items_to_json( lt_items_json ).

      " Build final result
      ls_result-lineitemsjson = lv_json_string.

      APPEND ls_result TO lt_result.
      CLEAR ls_result.
    ENDLOOP.

    " Sorting
    DATA(sort_order) = VALUE abap_sortorder_tab(
      FOR sort_element IN io_request->get_sort_elements( )
      ( name = sort_element-element_name descending = sort_element-descending ) ).
    IF sort_order IS NOT INITIAL.
      SORT lt_result BY (sort_order).
    ENDIF.

    DATA(lv_total_records) = lines( lt_result ).

    DATA(lo_paging) = io_request->get_paging( ).
    IF lo_paging IS BOUND.
      DATA(top) = lo_paging->get_page_size( ).
      IF top < 0. " -1 means all records
        top = lv_total_records.
      ENDIF.
      DATA(skip) = lo_paging->get_offset( ).

      IF skip >= lv_total_records.
        CLEAR lt_result. " Offset is beyond the total number of records
      ELSEIF top = 0.
        CLEAR lt_result. " No records requested
      ELSE.
        " Calculate the actual range to keep
        DATA(lv_start_index) = skip + 1. " ABAP uses 1-based indexing
        DATA(lv_end_index) = skip + top.

        " Ensure end index doesn't exceed table size
        IF lv_end_index > lv_total_records.
          lv_end_index = lv_total_records.
        ENDIF.

        " Create a new table with only the required records
        DATA: lt_paged_result LIKE lt_result.
        CLEAR lt_paged_result.

        " Copy only the required records
        DATA(lv_index) = lv_start_index.
        WHILE lv_index <= lv_end_index.
          APPEND lt_result[ lv_index ] TO lt_paged_result.
          lv_index = lv_index + 1.
        ENDWHILE.

        lt_result = lt_paged_result.
      ENDIF.
    ENDIF.
    " 6. Set response
    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
  ENDMETHOD.


  METHOD convert_line_items_to_json.
    " Convert internal table to JSON string
    DATA: lo_writer TYPE REF TO cl_sxml_string_writer.

    lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).

    CALL TRANSFORMATION id
      SOURCE line_items = it_line_items
      RESULT XML lo_writer.

    rv_json = cl_abap_conv_codepage=>create_in( )->convert( lo_writer->get_output( ) ).
  ENDMETHOD.
ENDCLASS.
