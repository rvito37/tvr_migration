// htmlout.prg
// Convert TVR text file output to HTML
//
// After rpGenReport() writes a text file via rpPRINTER_FILE,
// TextToHtml() reads it and creates an HTML file with the same
// content wrapped in <pre> tags.  Form-feed characters (chr 12)
// become visual page breaks.  Printer escape codes are stripped.
//
// No changes to PAGEOUT.PRG or any TVR library files required.

#include "avxdefs.ch"

#define CRLF  Chr(13)+Chr(10)

/*========================================================================*/
FUNCTION TextToHtml( cTextFile, cHtmlFile )
/*
 *  Read the text file produced by rpPRINTER_FILE and write an
 *  HTML file with identical visual layout.
 *
 *  cTextFile - full path to the text file (no extension)
 *  cHtmlFile - full path for the output .html file
 *
 *  Returns .T. on success, .F. on failure
 */
LOCAL nIn, nOut
LOCAL cBuf, cClean
LOCAL cHeader, cFooter
LOCAL nFF

nIn := FOPEN( cTextFile, 0 )
IF nIn <= 0
   RETURN .F.
ENDIF

nOut := FCREATE( cHtmlFile )
IF nOut <= 0
   FCLOSE( nIn )
   RETURN .F.
ENDIF

cHeader := '<!DOCTYPE html>'                                      + CRLF +;
           '<html>'                                               + CRLF +;
           '<head>'                                               + CRLF +;
           '<meta charset="windows-1255">'                        + CRLF +;
           '<style>'                                              + CRLF +;
           'body { margin: 10px; background: #fff; }'             + CRLF +;
           'pre  { font-family: "Courier New", monospace;'        + CRLF +;
           '       font-size: 10pt; line-height: 1.2;'           + CRLF +;
           '       white-space: pre; margin: 0; }'                + CRLF +;
           '.page-break { border-top: 1px dashed #999;'          + CRLF +;
           '              margin: 8px 0; }'                       + CRLF +;
           '@media print {'                                       + CRLF +;
           '  .page-break { page-break-before: always;'          + CRLF +;
           '                border: none; margin: 0; }'          + CRLF +;
           '}'                                                    + CRLF +;
           '</style>'                                             + CRLF +;
           '</head>'                                              + CRLF +;
           '<body>'                                               + CRLF +;
           '<pre>'                                                + CRLF

FWRITE( nOut, cHeader )

* read text file line by line using freadstr
* freadstr reads up to N bytes and stops at CR/LF
DO WHILE .T.
   cBuf := freadstr( nIn, 4096 )
   IF Len( cBuf ) == 0
      EXIT
   ENDIF

   * strip printer escape codes (ESC sequences and control chars)
   cClean := StripPCodes( cBuf )

   * skip empty lines that were only printer codes
   IF Len( cClean ) == 0
      LOOP
   ENDIF

   * check for form-feed in this line
   nFF := At( Chr(12), cClean )
   IF nFF > 0
      * has form-feed - write text before it, then page break
      IF nFF > 1
         FWRITE( nOut, HtmlEsc( Left( cClean, nFF - 1 ) ) + CRLF )
      ENDIF
      FWRITE( nOut, '</pre>' + CRLF +;
                     '<div class="page-break"></div>' + CRLF +;
                     '<pre>' + CRLF )
      * if there is text after the form-feed, write it too
      IF nFF < Len( cClean )
         FWRITE( nOut, HtmlEsc( SubStr( cClean, nFF + 1 ) ) + CRLF )
      ENDIF
   ELSE
      * normal line
      FWRITE( nOut, HtmlEsc( cClean ) + CRLF )
   ENDIF
ENDDO
FCLOSE( nIn )

cFooter := '</pre>'    + CRLF +;
           '</body>'   + CRLF +;
           '</html>'   + CRLF

FWRITE( nOut, cFooter )
FCLOSE( nOut )

RETURN .T.
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION StripPCodes( cStr )
/*
 *  Remove printer escape sequences from the line.
 *  PCL codes start with chr(27) (ESC) and run until an uppercase
 *  letter A-Z is found (the PCL command terminator).
 *  Also strips any remaining control chars below chr(32)
 *  except chr(12) form-feed which we use for page breaks.
 */
LOCAL cOut, nK, nC, lInEsc

cOut   := ""
lInEsc := .F.

FOR nK := 1 TO Len( cStr )
   nC := Asc( SubStr( cStr, nK, 1 ) )

   IF lInEsc
      * inside ESC sequence - look for terminator (uppercase letter)
      IF nC >= 65 .AND. nC <= 90
         * A-Z = end of ESC sequence
         lInEsc := .F.
      ENDIF
      * skip all chars in ESC sequence
      LOOP
   ENDIF

   IF nC == 27
      * ESC - start of escape sequence
      lInEsc := .T.
      LOOP
   ENDIF

   IF nC < 32 .AND. nC <> 12
      * control char (not form-feed) - skip it
      LOOP
   ENDIF

   * normal printable char or form-feed - keep it
   cOut := cOut + Chr( nC )
NEXT

RETURN cOut
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION HtmlEsc( cStr )
/*
 *  Escape HTML special characters for display inside <pre> block
 */
cStr := STRTRAN( cStr, "&" , "&amp;"  )
cStr := STRTRAN( cStr, "<" , "&lt;"   )
cStr := STRTRAN( cStr, ">" , "&gt;"   )
cStr := STRTRAN( cStr, '"' , "&quot;" )
RETURN cStr
/*========================================================================*/
