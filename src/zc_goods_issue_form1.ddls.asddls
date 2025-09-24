@EndUserText.label: 'Upload file action'
define abstract entity ZC_Goods_Issue_Form1
{
  mimeType      : abap.string(0);
  fileName      : abap.string(0);
  fileContent   : abap.rawstring(0);
  fileExtension : abap.string(0);
}
