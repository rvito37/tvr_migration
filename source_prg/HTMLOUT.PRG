// htmlout.prg
// HTML output functions for report engine
// Replaces printer/file output with HTML file generation
//
// Usage: called from rpPageOut() when destination is rpHTML
//
// The aPage[] array received from rpGenReport() contains fully
// formatted monospace text lines (headers, body, footers, borders).
// We wrap them in <pre> tags so the HTML looks identical to print.

#include "avxdefs.ch"

STATIC nHtmlHandle  := 0
STATIC lHtmlStarted := .F.

/*========================================================================*/
FUNCTION HtmlOpen( cFileName )
/*
 *  Open HTML file and write the document header.
 *  Called once before the first page.
 *  cFileName - full path including .html extension
 *  Returns   - file handle ( > 0 on success )
 */
LOCAL cHeader

nHtmlHandle := FCREATE( cFileName )
IF nHtmlHandle <= 0
   RETURN 0
ENDIF

cHeader := '<!DOCTYPE html>'                                      + Chr(13)+Chr(10) +;
           '<html>'                                               + Chr(13)+Chr(10) +;
           '<head>'                                               + Chr(13)+Chr(10) +;
           '<meta charset="windows-1255">'                        + Chr(13)+Chr(10) +;
           '<style>'                                              + Chr(13)+Chr(10) +;
           'body { margin: 10px; background: #fff; }'             + Chr(13)+Chr(10) +;
           'pre  { font-family: "Courier New", monospace;'        + Chr(13)+Chr(10) +;
           '       font-size: 10pt; line-height: 1.2;'           + Chr(13)+Chr(10) +;
           '       white-space: pre; margin: 0; }'                + Chr(13)+Chr(10) +;
           '.page-break { border-top: 1px dashed #999;'          + Chr(13)+Chr(10) +;
           '              margin: 8px 0; }'                       + Chr(13)+Chr(10) +;
           '@media print {'                                       + Chr(13)+Chr(10) +;
           '  .page-break { page-break-before: always;'          + Chr(13)+Chr(10) +;
           '                border: none; margin: 0; }'          + Chr(13)+Chr(10) +;
           '}'                                                    + Chr(13)+Chr(10) +;
           '</style>'                                             + Chr(13)+Chr(10) +;
           '</head>'                                              + Chr(13)+Chr(10) +;
           '<body>'                                               + Chr(13)+Chr(10) +;
           '<pre>'                                                + Chr(13)+Chr(10)

FWRITE( nHtmlHandle, cHeader )
lHtmlStarted := .T.

RETURN nHtmlHandle
/*========================================================================*/

/*========================================================================*/
FUNCTION HtmlPageOut( aPage )
/*
 *  Write one page of report output to the HTML file.
 *  Called by rpPageOut() for each page that rpGenReport() renders.
 *  aPage - array of character strings (one per line), may contain
 *          chr(12) form-feed characters for page breaks.
 */
LOCAL nK
LOCAL cLine

IF nHtmlHandle <= 0
   RETURN NIL
ENDIF

FOR nK := 1 TO Len( aPage )

    IF At( Chr(12), aPage[nK] ) > 0
       // Form feed - page break
       cLine := STRTRAN( aPage[nK], Chr(12), "" )
       IF !Empty( cLine )
          FWRITE( nHtmlHandle, HtmlEscape( cLine ) + Chr(13)+Chr(10) )
       ENDIF
       FWRITE( nHtmlHandle, '</pre>' + Chr(13)+Chr(10) +;
                            '<div class="page-break"></div>' + Chr(13)+Chr(10) +;
                            '<pre>' + Chr(13)+Chr(10) )
    ELSE
       FWRITE( nHtmlHandle, HtmlEscape( aPage[nK] ) + Chr(13)+Chr(10) )
    ENDIF

NEXT

RETURN NIL
/*========================================================================*/

/*========================================================================*/
FUNCTION HtmlClose()
/*
 *  Write closing tags and close the HTML file.
 *  Called once after all pages are output.
 */
IF nHtmlHandle > 0
   FWRITE( nHtmlHandle, '</pre>'    + Chr(13)+Chr(10) +;
                        '</body>'   + Chr(13)+Chr(10) +;
                        '</html>'   + Chr(13)+Chr(10) )
   FCLOSE( nHtmlHandle )
ENDIF

nHtmlHandle  := 0
lHtmlStarted := .F.

RETURN NIL
/*========================================================================*/

/*========================================================================*/
FUNCTION HtmlEscape( cStr )
/*
 *  Escape HTML special characters so the line displays correctly
 *  inside a <pre> block.
 */
cStr := STRTRAN( cStr, "&" , "&amp;"  )
cStr := STRTRAN( cStr, "<" , "&lt;"   )
cStr := STRTRAN( cStr, ">" , "&gt;"   )
cStr := STRTRAN( cStr, '"' , "&quot;" )

RETURN cStr
/*========================================================================*/

/*========================================================================*/
FUNCTION HtmlHandle()
/*
 *  Returns the current HTML file handle.
 *  Used by rpPageOut() and rpPrintReset().
 */
RETURN nHtmlHandle
/*========================================================================*/

/*========================================================================*/
FUNCTION HtmlIsOpen()
/*
 *  Returns .T. if HTML file is currently open.
 */
RETURN lHtmlStarted
/*========================================================================*/
