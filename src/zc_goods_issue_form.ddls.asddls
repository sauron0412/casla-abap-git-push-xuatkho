@EndUserText.label: 'Material Documents (Header + Items JSON)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_GOODS_ISSUE_FORM_QUERY'
@Metadata.allowExtensions: true
define root custom entity ZC_Goods_Issue_Form
{
    @Consumption.filter: { mandatory: true, multipleSelections: true }
    key MaterialDocument     : mblnr;          // MBLNR - Material Document Number

    @Consumption.filter: { mandatory: true, multipleSelections: false }
    key FiscalYear           : gjahr;          // GJAHR - Fiscal Year

    @Consumption.filter: { multipleSelections: true }
    CompanyCode              : bukrs;          // BUKRS - Company Code

    @Consumption.filter: { multipleSelections: true }
    SalesOrderNumber         : vbeln_va;       // VBELN - Sales Order (PXK thường liên quan SO)

    @Consumption.filter: { multipleSelections: true }
    NumberOfReservation      : rsnum;          // RSNUM - Reservation Number

    @Consumption.filter: { multipleSelections: true }
    MaterialDocumentDate     : budat;          // BUDAT - Posting Date (thay vì BLDAT)

    @Consumption.filter: { multipleSelections: true }
    CustomerName             : abap.char(50);  // Customer Name

    @Consumption.filter: { multipleSelections: true }
    PlantName                : abap.char(60);  // T001W-NAME2 - Plant Name

    @Consumption.filter: { multipleSelections: true }
    DocumentHeaderText       : abap.char(50);  // BKTXT - Document Header Text

    @Consumption.filter: { multipleSelections: true }
    PostingDate              : budat;          // BUDAT - Posting Date

    // Optional fields (nếu cần)
    HeadOfDepartment         : abap.char(100); // Head of Department Name
    Cashier                  : abap.char(100); // Cashier Name
    Director                 : abap.char(100); // Director Name
    Department               : abap.char(255); // Department Name

    // Line items as JSON string
    LineItemsJson            : abap.string;    // JSON representation of line items
}
