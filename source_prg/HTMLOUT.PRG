// htmlout.prg
// Convert TVR text file output to HTML
//
// After rpGenReport() writes a text file via rpPRINTER_FILE,
// TextToHtml() reads it and creates an HTML file with the same
// content wrapped in <pre> tags.  Form-feed characters (chr 12)
// become visual page breaks.  Printer escape codes are stripped.
// CP862 bytes are converted to UTF-8.
//
// No changes to PAGEOUT.PRG or any TVR library files required.

#include "avxdefs.ch"

#define CRLF  Chr(13)+Chr(10)

STATIC aCP862       // CP862 to UTF-8 lookup table (built once)

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
LOCAL nIn, nOut, nRead
LOCAL cText, cClean, cBuf, cChunk
LOCAL cHeader, cFooter
LOCAL nFF, nPos, nNext

* build CP862->UTF8 table on first call
IF aCP862 == NIL
   BuildCP862()
ENDIF

* read entire text file into memory using FREAD (not memoread which
* stops at Chr(26) soft-EOF marker that TVR may write)
nIn := FOPEN( cTextFile, 0 )
IF nIn <= 0
   RETURN .F.
ENDIF
cText  := ""
cChunk := space( 4096 )
DO WHILE .T.
   nRead := FREAD( nIn, @cChunk, 4096 )
   IF nRead <= 0
      EXIT
   ENDIF
   cText := cText + Left( cChunk, nRead )
ENDDO
FCLOSE( nIn )
IF Len( cText ) == 0
   RETURN .F.
ENDIF

nOut := FCREATE( cHtmlFile )
IF nOut <= 0
   RETURN .F.
ENDIF

cHeader := '<!DOCTYPE html>'                                      + CRLF +;
           '<html>'                                               + CRLF +;
           '<head>'                                               + CRLF +;
           '<meta charset="UTF-8">'                               + CRLF +;
           '<style>'                                              + CRLF +;
           'body { margin: 10px; background: #fff; }'             + CRLF +;
           'pre  { font-family: "Courier New", monospace;'        + CRLF +;
           '       font-size: 10pt; line-height: 1.2;'           + CRLF +;
           '       white-space: pre; margin: 0;'                 + CRLF +;
           '       unicode-bidi: bidi-override;'                 + CRLF +;
           '       direction: ltr; }'                             + CRLF +;
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

* walk through text splitting on CR (chr 13)
nPos := 1
DO WHILE nPos <= Len( cText )

   * find next CR
   nNext := At( Chr(13), SubStr( cText, nPos ) )

   IF nNext > 0
      * extract line (without CR)
      cBuf := SubStr( cText, nPos, nNext - 1 )
      * advance past CR and optional LF
      nPos := nPos + nNext
      IF nPos <= Len( cText ) .AND. SubStr( cText, nPos, 1 ) == Chr(10)
         nPos := nPos + 1
      ENDIF
   ELSE
      * last chunk, no more CR
      cBuf := SubStr( cText, nPos )
      nPos := Len( cText ) + 1
   ENDIF

   * strip printer escape codes
   cClean := StripPCodes( cBuf )

   * convert CP862 to UTF-8 and escape HTML
   cClean := ConvLine( cClean )

   * check for form-feed in this line
   nFF := At( Chr(12), cClean )
   IF nFF > 0
      IF nFF > 1
         FWRITE( nOut, Left( cClean, nFF - 1 ) + CRLF )
      ENDIF
      FWRITE( nOut, '</pre>' + CRLF +;
                     '<div class="page-break"></div>' + CRLF +;
                     '<pre>' + CRLF )
      IF nFF < Len( cClean )
         cBuf := SubStr( cClean, nFF + 1 )
         IF Len( cBuf ) > 0
            FWRITE( nOut, cBuf + CRLF )
         ENDIF
      ENDIF
   ELSE
      FWRITE( nOut, cClean + CRLF )
   ENDIF

ENDDO

cFooter := '</pre>'    + CRLF +;
           '</body>'   + CRLF +;
           '</html>'   + CRLF

FWRITE( nOut, cFooter )
FCLOSE( nOut )

RETURN .T.
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION ConvLine( cStr )
/*
 *  Convert one line from CP862 to UTF-8, and escape HTML chars.
 *  Each byte 0x80-0xFF is replaced with its UTF-8 equivalent
 *  from the lookup table.  ASCII chars are kept as-is except
 *  the HTML special chars & < > " which are escaped.
 */
LOCAL cOut, nK, nC, cCh

cOut := ""
FOR nK := 1 TO Len( cStr )
   nC := Asc( SubStr( cStr, nK, 1 ) )
   IF nC >= 128
      * high byte - lookup UTF-8 replacement
      cOut := cOut + aCP862[ nC - 127 ]
   ELSEIF nC == 38
      * & -> &amp;
      cOut := cOut + "&amp;"
   ELSEIF nC == 60
      * < -> &lt;
      cOut := cOut + "&lt;"
   ELSEIF nC == 62
      * > -> &gt;
      cOut := cOut + "&gt;"
   ELSEIF nC == 34
      * " -> &quot;
      cOut := cOut + "&quot;"
   ELSEIF nC == 12
      * form-feed - keep as-is for page break detection
      cOut := cOut + Chr(12)
   ELSEIF nC >= 32
      * normal printable ASCII
      cOut := cOut + Chr( nC )
   ENDIF
NEXT

RETURN cOut
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
      IF nC >= 65 .AND. nC <= 90
         lInEsc := .F.
      ENDIF
      LOOP
   ENDIF

   IF nC == 27
      lInEsc := .T.
      LOOP
   ENDIF

   IF nC < 32 .AND. nC <> 12
      LOOP
   ENDIF

   cOut := cOut + Chr( nC )
NEXT

RETURN cOut
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION BuildCP862()
/*
 *  Build lookup table: aCP862[1..128] maps bytes 0x80..0xFF
 *  to their UTF-8 string equivalents.
 *
 *  CP862 layout:
 *    0x80-0x9A = Hebrew Alef-Tav  (Unicode 05D0-05EA)
 *    0x9B-0x9F = misc currency/symbols
 *    0xA0-0xA9 = more symbols
 *    0xB0-0xDF = box drawing
 *    0xE0-0xEF = more symbols / Greek
 *    0xF0-0xFF = misc
 *
 *  For Hebrew: Unicode 05D0 + (byte - 0x80)
 *    UTF-8 encoding of U+05D0..U+05EA = 0xD7 0x90..0xD7 0xAA
 */
LOCAL nK, nUni

aCP862 := Array( 128 )

* Hebrew letters: 0x80..0x9A -> U+05D0..U+05EA
* UTF-8: 2 bytes = 0xD7, 0x90 + (n - 0x80)
FOR nK := 0 TO 26
   nUni := 144 + nK     // 0x90 + nK  (second byte of UTF-8)
   aCP862[ nK + 1 ] := Chr( 215 ) + Chr( nUni )  // 0xD7 = 215
NEXT

* Fill rest with reasonable defaults
* 0x9B..0x9F (indices 28..32): currency/fraction symbols
aCP862[ 28 ] := Chr(194) + Chr(162)     // cent sign
aCP862[ 29 ] := Chr(194) + Chr(163)     // pound sign
aCP862[ 30 ] := Chr(194) + Chr(165)     // yen sign
aCP862[ 31 ] := Chr(226) + Chr(130) + Chr(167)  // peseta
aCP862[ 32 ] := Chr(198) + Chr(146)     // florin

* 0xA0..0xA9 (indices 33..42): accented + symbols
aCP862[ 33 ] := Chr(195) + Chr(161)     // a acute
aCP862[ 34 ] := Chr(195) + Chr(173)     // i acute
aCP862[ 35 ] := Chr(195) + Chr(179)     // o acute
aCP862[ 36 ] := Chr(195) + Chr(186)     // u acute
aCP862[ 37 ] := Chr(195) + Chr(177)     // n tilde
aCP862[ 38 ] := Chr(195) + Chr(145)     // N tilde
aCP862[ 39 ] := Chr(194) + Chr(170)     // feminine ordinal
aCP862[ 40 ] := Chr(194) + Chr(186)     // masculine ordinal
aCP862[ 41 ] := Chr(194) + Chr(191)     // inverted question
aCP862[ 42 ] := Chr(226) + Chr(140) + Chr(144)  // reversed not

* 0xAA..0xAF (indices 43..48)
aCP862[ 43 ] := Chr(194) + Chr(172)     // not sign
aCP862[ 44 ] := Chr(194) + Chr(189)     // 1/2
aCP862[ 45 ] := Chr(194) + Chr(188)     // 1/4
aCP862[ 46 ] := Chr(194) + Chr(161)     // inverted exclamation
aCP862[ 47 ] := Chr(194) + Chr(171)     // left guillemet
aCP862[ 48 ] := Chr(194) + Chr(187)     // right guillemet

* Box drawing: 0xB0..0xDF (indices 49..96)
* Using UTF-8 encoded box drawing characters (U+2500 range)
* These are 3-byte UTF-8 sequences: E2 xx xx

aCP862[ 49 ] := Chr(226) + Chr(150) + Chr(145)  // 0xB0 light shade
aCP862[ 50 ] := Chr(226) + Chr(150) + Chr(146)  // 0xB1 medium shade
aCP862[ 51 ] := Chr(226) + Chr(150) + Chr(147)  // 0xB2 dark shade
aCP862[ 52 ] := Chr(226) + Chr(148) + Chr(130)  // 0xB3 │ vertical
aCP862[ 53 ] := Chr(226) + Chr(148) + Chr(164)  // 0xB4 ┤
aCP862[ 54 ] := Chr(226) + Chr(149) + Chr(161)  // 0xB5 ╡
aCP862[ 55 ] := Chr(226) + Chr(149) + Chr(162)  // 0xB6 ╢
aCP862[ 56 ] := Chr(226) + Chr(149) + Chr(150)  // 0xB7 ╖
aCP862[ 57 ] := Chr(226) + Chr(149) + Chr(149)  // 0xB8 ╕
aCP862[ 58 ] := Chr(226) + Chr(149) + Chr(163)  // 0xB9 ╣
aCP862[ 59 ] := Chr(226) + Chr(149) + Chr(145)  // 0xBA ║
aCP862[ 60 ] := Chr(226) + Chr(149) + Chr(151)  // 0xBB ╗
aCP862[ 61 ] := Chr(226) + Chr(149) + Chr(157)  // 0xBC ╝
aCP862[ 62 ] := Chr(226) + Chr(149) + Chr(156)  // 0xBD ╜
aCP862[ 63 ] := Chr(226) + Chr(149) + Chr(155)  // 0xBE ╛
aCP862[ 64 ] := Chr(226) + Chr(148) + Chr(144)  // 0xBF ┐
aCP862[ 65 ] := Chr(226) + Chr(148) + Chr(148)  // 0xC0 └
aCP862[ 66 ] := Chr(226) + Chr(148) + Chr(180)  // 0xC1 ┴
aCP862[ 67 ] := Chr(226) + Chr(148) + Chr(172)  // 0xC2 ┬
aCP862[ 68 ] := Chr(226) + Chr(148) + Chr(156)  // 0xC3 ├
aCP862[ 69 ] := Chr(226) + Chr(148) + Chr(128)  // 0xC4 ─ horizontal
aCP862[ 70 ] := Chr(226) + Chr(148) + Chr(188)  // 0xC5 ┼
aCP862[ 71 ] := Chr(226) + Chr(149) + Chr(158)  // 0xC6 ╞
aCP862[ 72 ] := Chr(226) + Chr(149) + Chr(159)  // 0xC7 ╟
aCP862[ 73 ] := Chr(226) + Chr(149) + Chr(154)  // 0xC8 ╚
aCP862[ 74 ] := Chr(226) + Chr(149) + Chr(148)  // 0xC9 ╔
aCP862[ 75 ] := Chr(226) + Chr(149) + Chr(169)  // 0xCA ╩
aCP862[ 76 ] := Chr(226) + Chr(149) + Chr(166)  // 0xCB ╦
aCP862[ 77 ] := Chr(226) + Chr(149) + Chr(160)  // 0xCC ╠
aCP862[ 78 ] := Chr(226) + Chr(149) + Chr(144)  // 0xCD ═
aCP862[ 79 ] := Chr(226) + Chr(149) + Chr(172)  // 0xCE ╬
aCP862[ 80 ] := Chr(226) + Chr(149) + Chr(167)  // 0xCF ╧
aCP862[ 81 ] := Chr(226) + Chr(149) + Chr(168)  // 0xD0 ╨
aCP862[ 82 ] := Chr(226) + Chr(149) + Chr(164)  // 0xD1 ╤
aCP862[ 83 ] := Chr(226) + Chr(149) + Chr(165)  // 0xD2 ╥
aCP862[ 84 ] := Chr(226) + Chr(149) + Chr(153)  // 0xD3 ╙
aCP862[ 85 ] := Chr(226) + Chr(149) + Chr(152)  // 0xD4 ╘
aCP862[ 86 ] := Chr(226) + Chr(149) + Chr(146)  // 0xD5 ╒
aCP862[ 87 ] := Chr(226) + Chr(149) + Chr(147)  // 0xD6 ╓
aCP862[ 88 ] := Chr(226) + Chr(149) + Chr(171)  // 0xD7 ╫
aCP862[ 89 ] := Chr(226) + Chr(149) + Chr(170)  // 0xD8 ╪
aCP862[ 90 ] := Chr(226) + Chr(148) + Chr(152)  // 0xD9 ┘
aCP862[ 91 ] := Chr(226) + Chr(148) + Chr(140)  // 0xDA ┌
aCP862[ 92 ] := Chr(226) + Chr(150) + Chr(136)  // 0xDB █ full block
aCP862[ 93 ] := Chr(226) + Chr(150) + Chr(132)  // 0xDC ▄ lower half
aCP862[ 94 ] := Chr(226) + Chr(150) + Chr(140)  // 0xDD ▌ left half
aCP862[ 95 ] := Chr(226) + Chr(150) + Chr(144)  // 0xDE ▐ right half
aCP862[ 96 ] := Chr(226) + Chr(150) + Chr(128)  // 0xDF ▀ upper half

* 0xE0..0xEF (indices 97..112): Greek/math symbols
aCP862[ 97 ]  := Chr(206) + Chr(177)     // alpha
aCP862[ 98 ]  := Chr(195) + Chr(159)     // sharp s
aCP862[ 99 ]  := Chr(206) + Chr(147)     // Gamma
aCP862[ 100 ] := Chr(207) + Chr(128)     // pi
aCP862[ 101 ] := Chr(206) + Chr(163)     // Sigma
aCP862[ 102 ] := Chr(207) + Chr(131)     // sigma
aCP862[ 103 ] := Chr(194) + Chr(181)     // mu
aCP862[ 104 ] := Chr(207) + Chr(132)     // tau
aCP862[ 105 ] := Chr(206) + Chr(166)     // Phi
aCP862[ 106 ] := Chr(206) + Chr(152)     // Theta
aCP862[ 107 ] := Chr(206) + Chr(169)     // Omega
aCP862[ 108 ] := Chr(206) + Chr(180)     // delta
aCP862[ 109 ] := Chr(226) + Chr(136) + Chr(158)  // infinity
aCP862[ 110 ] := Chr(207) + Chr(134)     // phi
aCP862[ 111 ] := Chr(206) + Chr(181)     // epsilon
aCP862[ 112 ] := Chr(226) + Chr(136) + Chr(169)  // intersection

* 0xF0..0xFF (indices 113..128): misc math/symbols
aCP862[ 113 ] := Chr(226) + Chr(137) + Chr(161)  // identical to
aCP862[ 114 ] := Chr(194) + Chr(177)     // plus-minus
aCP862[ 115 ] := Chr(226) + Chr(137) + Chr(165)  // >=
aCP862[ 116 ] := Chr(226) + Chr(137) + Chr(164)  // <=
aCP862[ 117 ] := Chr(226) + Chr(136) + Chr(171)  // integral top
aCP862[ 118 ] := Chr(226) + Chr(136) + Chr(172)  // integral bottom
aCP862[ 119 ] := Chr(195) + Chr(183)     // division
aCP862[ 120 ] := Chr(226) + Chr(137) + Chr(136)  // approx equal
aCP862[ 121 ] := Chr(194) + Chr(176)     // degree
aCP862[ 122 ] := Chr(226) + Chr(136) + Chr(153)  // bullet
aCP862[ 123 ] := Chr(194) + Chr(183)     // middle dot
aCP862[ 124 ] := Chr(226) + Chr(136) + Chr(154)  // sqrt
aCP862[ 125 ] := Chr(226) + Chr(129) + Chr(191)  // superscript n
aCP862[ 126 ] := Chr(194) + Chr(178)     // superscript 2
aCP862[ 127 ] := Chr(226) + Chr(150) + Chr(160)  // black square
aCP862[ 128 ] := Chr(194) + Chr(160)     // nbsp

RETURN NIL
/*========================================================================*/
