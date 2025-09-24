CLASS zcl_pdf_reportt DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Kiểu cho action keys / results (giữ nguyên như bạn đã khai báo)
    TYPES:
      keys_pxk     TYPE TABLE FOR ACTION IMPORT ZC_Goods_Issue_Form~btnPrintPDF,
      result_pxk   TYPE TABLE FOR ACTION RESULT ZC_Goods_Issue_Form~btnPrintPDF,
      mapped_pxk   TYPE RESPONSE FOR MAPPED EARLY ZC_Goods_Issue_Form,
      failed_pxk   TYPE RESPONSE FOR FAILED EARLY ZC_Goods_Issue_Form,
      reported_pxk TYPE RESPONSE FOR REPORTED EARLY ZC_Goods_Issue_Form.
*



    CLASS-METHODS:
      btnPrintPDF_PXK IMPORTING keys     TYPE keys_pxk
                       EXPORTING o_pdf    TYPE xstring
                       CHANGING  result   TYPE result_pxk
                                 mapped   TYPE mapped_pxk
                                 failed   TYPE failed_pxk
                                 reported TYPE reported_pxk.

  PRIVATE SECTION.

    " Header JSON cho phiếu xuất kho
    TYPES: BEGIN OF ty_header_json,
             materialdocument       TYPE mblnr,
             fiscalyear             TYPE mjahr,
             companycode            TYPE bukrs,
             purchaseordernumber    TYPE ebeln,
             numberofreservation    TYPE rsnum,
             materialdocumentdate   TYPE budat,
             vendorname             TYPE c LENGTH 100,
             plantname              TYPE c LENGTH 60,
             documentheadertext     TYPE c LENGTH 50,
             companyname            TYPE c LENGTH 100,
             postingdate            TYPE budat,
             " Thêm các field fix cứng cho Phiếu Xuất Kho
             deliveryperson         TYPE c LENGTH 100, "Người giao hàng
             unitname               TYPE c LENGTH 60,  "Đơn vị
             contenttext            TYPE c LENGTH 255, "Nội dung
             storagelocationname    TYPE c LENGTH 60,  "Kho
           END OF ty_header_json.

    " Item JSON cho phiếu xuất kho
    TYPES: BEGIN OF ty_item_json,
             numberoforder           TYPE string,
             materialnumber          TYPE matnr,
             batchnumber             TYPE charg_d,
             materialdescription     TYPE maktx,
             unitofmeasurementtext   TYPE msehl,
             salesordernumber        TYPE vbeln_va,
             salesorderitem          TYPE posnr,
             quantityinunitofentry   TYPE erfmg,
             purchaseorderquantity   TYPE menge_d,
             amountinlocalcurrency   TYPE wrbtr,
             unitprice               TYPE wrbtr,
             currencykey             TYPE waers,
           END OF ty_item_json.

    CLASS-DATA:
      ir_fiscalyear        TYPE zcl_goods_issue_form_query=>tt_ranges,
      ir_MaterialDocument  TYPE zcl_goods_issue_form_query=>tt_ranges.

    TYPES tt_item_json TYPE STANDARD TABLE OF ty_item_json WITH EMPTY KEY.

ENDCLASS.



CLASS ZCL_PDF_REPORTT IMPLEMENTATION.


  METHOD btnPrintPDF_PXK.
    DATA: k               LIKE LINE OF keys,
          gs_header       TYPE ty_header_json,
          lt_items        TYPE tt_item_json,
          ls_item_json    TYPE ty_item_json,
          lv_total_amount TYPE p LENGTH 16 DECIMALS 2 VALUE 0,
          lv_items_xml    TYPE string,
          lv_xml          TYPE string.

    " --- 1. Lấy key đầu tiên
    READ TABLE keys INDEX 1 INTO k.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.


    APPEND VALUE #( sign = 'I' option = 'EQ' low = k-%key-fiscalyear ) TO ir_fiscalyear.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = k-%key-MaterialDocument ) TO  ir_MaterialDocument.


    " --- 2. Lấy dữ liệu phiếu nhập kho từ CDS/DB
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
      WHERE a~materialdocument IN @ir_MaterialDocument
        AND a~isautomaticallycreated <> 'X'
        AND a~materialdocumentyear IN @ir_fiscalyear
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

    " --- 3. Build header từ dòng đầu tiên
    READ TABLE lt_data INDEX 1 INTO DATA(ls_first_row).
    IF sy-subrc = 0.
gs_header = VALUE ty_header_json(
  materialdocument     = ls_first_row-materialdocument
  fiscalyear           = ls_first_row-materialdocumentyear
  companycode          = ls_first_row-companycode
  purchaseordernumber  = ls_first_row-purchaseorder
  numberofreservation  = ls_first_row-reservation
  materialdocumentdate = ls_first_row-postingdate
  vendorname           = ls_first_row-customername   " GFI
  plantname            = ls_first_row-plantname      " Nhà máy túi CASLA 1
  documentheadertext   = ls_first_row-materialdocumentheadertext
  postingdate          = ls_first_row-postingdate
).

    " Đọc item đầu tiên của MaterialDocument
    SELECT SINGLE *
      FROM i_materialdocumentitem_2
      WHERE MaterialDocument = @ls_first_row-materialdocument
      INTO @DATA(ls_matnr).

    DATA(lv_delivery_doc) = ``.
    DATA(lv_reservation)  = ``.

    IF sy-subrc = 0.

      " Nếu có DeliveryDocument => phiếu nhập kho từ PO
      IF ls_matnr-DeliveryDocument IS NOT INITIAL.
        lv_delivery_doc = ls_matnr-DeliveryDocument.
        SHIFT lv_delivery_doc LEFT DELETING LEADING '0'.  " Cắt số 0 đầu
       gs_header-numberofreservation = |{ lv_delivery_doc }|.

      " Nếu không có DeliveryDocument nhưng có Reservation => phiếu nhập xuất từ Reservation
      ELSEIF ls_matnr-Reservation IS NOT INITIAL.
        lv_reservation = ls_matnr-Reservation.
        SHIFT lv_reservation LEFT DELETING LEADING '0'.   " Cắt số 0 đầu
        gs_header-numberofreservation = lv_reservation.

      " Nếu không có cả hai
      ELSE.
        gs_header-numberofreservation = 'Không xác định nguồn xuất kho'.
      ENDIF.

    ENDIF.


    SELECT SINGLE storagelocation
      FROM i_materialdocumentheader_2
      WHERE materialdocument     = @ls_first_row-materialdocument
        AND materialdocumentyear = @ls_first_row-materialdocumentyear
      INTO @DATA(lv_storagelocation).
    " Sau khi lấy ra lv_storagelocation_name ở bước trên
      gs_header-storagelocationname = lv_storagelocation.

SELECT SINGLE companycode
  FROM i_materialdocumentitem_2
  WHERE materialdocument     = @ls_first_row-materialdocument
    AND materialdocumentyear = @ls_first_row-materialdocumentyear
  INTO @DATA(lv_companycode).

     DATA: lv_companycode1 TYPE bukrs.

*    lv_companycode = .

    zcl_jp_common_core=>get_companycode_details(
      EXPORTING
        i_companycode = ls_first_row-CompanyCode
      IMPORTING
        o_companycode = DATA(ls_companycode)
    ).

  " Format ngày theo kiểu tiếng Việt
  DATA(lv_date_str) = ||.
  DATA(lv_day)   = ls_first_row-postingdate+6(2).
  DATA(lv_month) = ls_first_row-postingdate+4(2).
  DATA(lv_year)  = ls_first_row-postingdate+0(4).
  lv_date_str = |Ngày { lv_day } tháng { lv_month } năm { lv_year }|.

  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN gs_header-vendorname WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN gs_header-vendorname WITH space.
  CONDENSE gs_header-vendorname.
    ENDIF.

" --- 4. Build bảng items theo kiểu phiếu kế toán ---


LOOP AT lt_data INTO DATA(ls_row).
  CLEAR ls_item_json.

  ls_item_json-numberoforder         = |{ sy-tabix }|.
  ls_item_json-materialnumber        = |{ ls_row-material ALPHA = OUT }|.
  ls_item_json-batchnumber           = |{ ls_row-batch ALPHA = OUT }|.
  ls_item_json-materialdescription   = ls_row-materialname.
  ls_item_json-unitofmeasurementtext = ls_row-unitofmeasurelongname.
  ls_item_json-salesordernumber      = ls_row-specialstockidfgsalesorder.
  ls_item_json-salesorderitem        = ls_row-specialstockidfgsalesorderitem.
  ls_item_json-quantityinunitofentry = ls_row-quantityinentryunit.

  ls_item_json-purchaseorderquantity =
    COND #( WHEN ls_row-purchaseorder IS NOT INITIAL AND ls_row-purchaseorderitem IS NOT INITIAL
            THEN ls_row-orderquantity
            WHEN ls_row-reservation IS NOT INITIAL AND ls_row-reservationitem IS NOT INITIAL
            THEN ls_row-resvnitmrequiredqtyinentryunit
            WHEN ls_row-specialstockidfgsalesorder IS NOT INITIAL AND ls_row-specialstockidfgsalesorderitem IS NOT INITIAL
            THEN ls_row-so_quantity
            WHEN ls_row-orderid IS NOT INITIAL AND ls_row-orderitem IS NOT INITIAL
            THEN ls_row-mfgorderitemplannedtotalqty
            WHEN ls_row-deliverydocument IS NOT INITIAL AND ls_row-deliverydocumentitem IS NOT INITIAL
            THEN ls_row-actualdeliveryquantity
            ELSE 0 ).

  ls_item_json-currencykey           = ls_row-companycodecurrency.
  ls_item_json-amountinlocalcurrency =
    COND #( WHEN ls_row-companycodecurrency = 'VND'
            THEN ls_row-totalgoodsmvtamtincccrcy * 100
            ELSE ls_row-totalgoodsmvtamtincccrcy ).

  ls_item_json-unitprice =
    COND #( WHEN ls_row-quantityinentryunit <> 0
            THEN COND #( WHEN ls_row-companycodecurrency = 'VND'
                         THEN round( val = ls_row-totalgoodsmvtamtincccrcy / ls_row-quantityinentryunit
                                     dec = 0 )
                         ELSE ls_row-totalgoodsmvtamtincccrcy / ls_row-quantityinentryunit )
            ELSE 0 ).

  APPEND ls_item_json TO lt_items.
  lv_total_amount += ls_item_json-amountinlocalcurrency.

  "--- Định dạng số liệu ---
  DATA(lv_qty_order)  = |{ ls_item_json-purchaseorderquantity DECIMALS = 0 NUMBER = USER }|.
  DATA(lv_qty_entry)  = |{ ls_item_json-quantityinunitofentry DECIMALS = 0 NUMBER = USER }|.
  DATA(lv_unitprice)  = |{ ls_item_json-unitprice DECIMALS = 0 NUMBER = USER }|.
  DATA(lv_amount)     = |{ ls_item_json-amountinlocalcurrency DECIMALS = 0 NUMBER = USER }|.

  DATA(lv_salesorder_xml) = ``.
  IF ls_item_json-salesordernumber IS NOT INITIAL OR ls_item_json-salesorderitem IS NOT INITIAL.
    lv_salesorder_xml = |<salesorder>{ ls_item_json-salesordernumber }/{ ls_item_json-salesorderitem }</salesorder>|.
  ENDIF.

  "--- Build từng Row1 và nối vào lv_rowsxml ---
  lv_xml = lv_xml &&
    |<Row1>| &&
    |<numberoforder>{ ls_item_json-numberoforder }</numberoforder>| &&
    |<materialnumber>{ ls_item_json-materialnumber }</materialnumber>| &&
    |<materialdescription>{ ls_item_json-materialdescription }</materialdescription>| &&
    |<batchnumber>{ ls_item_json-batchnumber }</batchnumber>| &&
    lv_salesorder_xml &&
    |<unitofmeasurementtext>{ ls_item_json-unitofmeasurementtext }</unitofmeasurementtext>| &&
    |<purchaseorderquantity>{ lv_qty_order }</purchaseorderquantity>| &&
    |<quantityinunitofentry>{ lv_qty_entry }</quantityinunitofentry>| &&
    |<unitprice>{ lv_unitprice }</unitprice>| &&
    |<amountinlocalcurrency>{ lv_amount }</amountinlocalcurrency>| &&
    |</Row1>|.
ENDLOOP.

" --- Định dạng tổng ---
DATA(lv_total_amount_str) = |{ lv_total_amount DECIMALS = 0 NUMBER = USER }|.
DATA(lv_po_num)  = gs_header-purchaseordernumber.
DATA(lv_po_fmt)  = ``.
DATA(lv_reservation_xml) = ``.
*IF ls_first_row-reservation IS NOT INITIAL.
*  lv_reservation_xml = |<Reservation>{ ls_first_row-reservation }</Reservation>|.
*ENDIF.

         DATA:lv_amount_for_read TYPE zde_dmbtr.
        lv_amount_for_read = lv_total_amount.
        lv_total_amount = abs( lv_total_amount ).
        DATA(lo_amount_in_words) = NEW zcore_cl_amount_in_words( ).
        data(lv_amount_text) = lo_amount_in_words->read_amount(
          EXPORTING
            i_amount = lv_amount_for_read
            i_lang   = 'VI'
            i_waers  = 'VND'
        ).


lv_xml =
|<?xml version="1.0" encoding="UTF-8"?>| &&
|<form1>| &&
|<main>| &&


  |<HeaderSection>| &&
  |<CompanyName>{ ls_companycode-companycodename }</CompanyName>| &&
  |<CompanyAddress>{ ls_companycode-companycodeaddr }</CompanyAddress>| &&
  |<Title>PHIẾU XUẤT KHO</Title>| &&
  |<MaterialDocumentDate>{ lv_date_str }</MaterialDocumentDate>| &&
  |<MaterialDocument>{ ls_first_row-MaterialDocument }</MaterialDocument>| &&
  |<Reservation>{ gs_header-numberofreservation }</Reservation>| &&
  |<PurchaseOrder>{ gs_header-purchaseordernumber }</PurchaseOrder>| &&
  |<Content1>{ gs_header-vendorname }</Content1>| &&
  |<Content2>{ gs_header-plantname }</Content2>| &&
  |<Content3>{ gs_header-contenttext }</Content3>| &&
  |<Content4>{ gs_header-storagelocationname }</Content4>| &&
  |</HeaderSection>| &&


|<MiddleSection>| &&
|<Table1>| &&
 |{ lv_xml }| &&
|<FooterRow>| &&
|<totalamount>{ lv_total_amount_str }</totalamount>| &&
|</FooterRow>| &&
|</Table1>| &&
|<amountinword>{ lv_amount_text }</amountinword>| &&
|</MiddleSection>| &&

  |<FooterSection>| &&
  |<PostingDate></PostingDate>| &&
  |<Table2>| &&
  |<Row1>| &&
  |<ChanKy1>Trưởng/phó đơn vị</ChanKy1>| &&
  |</Row1>| &&
  |<Row3>| &&
  |<ChanKy1></ChanKy1>| &&
  |<ChanKy2></ChanKy2>| &&
  |<ChanKy3></ChanKy3>| &&
  |</Row3>| &&
  |</Table2>| &&
  |</FooterSection>| &&

  |</main>| &&
  |</form1>|.




*" --- 8. Gọi generator để tạo PDF ---
*
*ls_request-id = 'zphieunhapkho'.
*APPEND lv_xml TO ls_request-data.
*
*" Tạo instance object generator
*lo_gen_adobe = NEW zcl_gen_adobe( ).
*
*" --- Gọi generator ---
*TRY.
*    lv_pdf = lo_gen_adobe->call_data(
*      EXPORTING
*        i_request = ls_request
*    ).
*
*  CATCH cx_root INTO DATA(lx_gen).
*    CLEAR result.
*    RETURN.
*ENDTRY.
*
*o_pdf = lv_pdf.
*
*" --- 9. Build kết quả trả về cho action ---
*result = VALUE #( FOR key IN keys (
*                    %tky = key-%tky
*                    %param = VALUE #(
*                      filecontent   = lv_pdf
*                      filename      = 'phieunhapkho'
*                      fileextension = 'pdf'
*                      mimetype      = 'application/pdf' )
*                  ) ).
*
*" --- 10. Cập nhật mapped ---
*DATA ls_mapped LIKE LINE OF mapped-GoodsReceiptForm.
*ls_mapped = VALUE #( ).
*ls_mapped-%tky = k-%tky.
*INSERT CORRESPONDING #( ls_mapped ) INTO TABLE mapped-GoodsReceiptForm.


 DATA: ls_request TYPE zcl_gen_adobe=>ts_request.

    ls_request-id = 'zphieuxuatkho'.
    APPEND lv_xml TO ls_request-data.

    DATA(o_gen_adobe) = NEW zcl_gen_adobe( ).

    DATA(lv_pdf) = o_gen_adobe->call_data( EXPORTING i_request = ls_request ).

    o_pdf = lv_pdf.

    DATA: lv_name TYPE string.

*    lv_name = |PhieuThu_{ ls_data-CompanyCode }{ ls_data-FiscalYear }{ ls_data-AccountingDocument }|.

    result = VALUE #( FOR key IN keys (
*                      %cid_ref = key-%cid_ref
                      %tky     = key-%tky
                      %param   = VALUE #( filecontent   = lv_pdf
                                          filename      =  'phieuxuatkho'
                                          fileextension = 'pdf'
*                                          mimeType      = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                                          mimetype      = 'application/pdf'
                                         )
                      ) ).
    DATA: ls_mapped LIKE LINE OF mapped-zc_goods_issue_form.
    ls_mapped-%tky = k-%tky.
    INSERT CORRESPONDING #( ls_mapped ) INTO TABLE mapped-zc_goods_issue_form.


  ENDMETHOD.

ENDCLASS.
