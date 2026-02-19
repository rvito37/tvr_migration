// htmlout.prg
// Convert TVR text file output to HTML
//
// After rpGenReport() writes a text file via rpPRINTER_FILE,
// TextToHtml() reads it and creates an HTML file with the same
// content wrapped in <pre> tags.  Form-feed characters (chr 12)
// become visual page breaks.  Printer escape codes are stripped.
// CP862 bytes are converted to UTF-8.
//
// Streaming approach: reads 4K blocks, extracts lines from buffer,
// writes HTML line by line.  Never holds entire file in memory.
//
// No changes to PAGEOUT.PRG or any TVR library files required.

#include "avxdefs.ch"

#define CRLF  Chr(13)+Chr(10)

STATIC aCP862       // CP862 to UTF-8 lookup table (built once)

/*========================================================================*/
FUNCTION TextToHtml( cTextFile, cHtmlFile )
LOCAL nIn, nOut, nRead
LOCAL cLeftOver, cChunk, cWork, cLine, cClean
LOCAL cHeader, cFooter
LOCAL nCR, nFF

* build CP862->UTF8 table on first call
IF aCP862 == NIL
   BuildCP862()
ENDIF

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

* streaming read: 4K blocks, extract lines by CR
cLeftOver := ""
cChunk    := space( 4096 )

DO WHILE .T.
   nRead := FREAD( nIn, @cChunk, 4096 )

   IF nRead > 0
      cWork := cLeftOver + Left( cChunk, nRead )
   ELSE
      * EOF - process whatever is left in buffer
      cWork := cLeftOver
      IF Len( cWork ) == 0
         EXIT
      ENDIF
   ENDIF

   * extract complete lines (terminated by CR)
   DO WHILE .T.
      nCR := At( Chr(13), cWork )
      IF nCR == 0
         * no more complete lines in buffer
         cLeftOver := cWork
         EXIT
      ENDIF

      * got a complete line
      cLine := Left( cWork, nCR - 1 )

      * advance past CR and optional LF
      IF nCR < Len( cWork ) .AND. SubStr( cWork, nCR + 1, 1 ) == Chr(10)
         cWork := SubStr( cWork, nCR + 2 )
      ELSE
         cWork := SubStr( cWork, nCR + 1 )
      ENDIF

      * process and write this line
      WriteLine( nOut, cLine )
   ENDDO

   IF nRead <= 0
      * EOF and leftover already processed above
      IF Len( cLeftOver ) > 0
         WriteLine( nOut, cLeftOver )
         cLeftOver := ""
      ENDIF
      EXIT
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
STATIC FUNCTION WriteLine( nOut, cRaw )
/*
 *  Process one raw line: strip PCL, convert CP862->UTF8, write HTML
 */
LOCAL cClean, nFF, cAfter

cClean := StripPCodes( cRaw )
cClean := ConvLine( cClean )

nFF := At( Chr(12), cClean )
IF nFF > 0
   IF nFF > 1
      FWRITE( nOut, Left( cClean, nFF - 1 ) + CRLF )
   ENDIF
   FWRITE( nOut, '</pre>' + CRLF +;
                  '<div class="page-break"></div>' + CRLF +;
                  '<pre>' + CRLF )
   IF nFF < Len( cClean )
      cAfter := SubStr( cClean, nFF + 1 )
      IF Len( cAfter ) > 0
         FWRITE( nOut, cAfter + CRLF )
      ENDIF
   ENDIF
ELSE
   FWRITE( nOut, cClean + CRLF )
ENDIF

RETURN NIL
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION ConvLine( cStr )
LOCAL cOut, nK, nC

cOut := ""
FOR nK := 1 TO Len( cStr )
   nC := Asc( SubStr( cStr, nK, 1 ) )
   IF nC >= 128
      cOut := cOut + aCP862[ nC - 127 ]
   ELSEIF nC == 38
      cOut := cOut + "&amp;"
   ELSEIF nC == 60
      cOut := cOut + "&lt;"
   ELSEIF nC == 62
      cOut := cOut + "&gt;"
   ELSEIF nC == 34
      cOut := cOut + "&quot;"
   ELSEIF nC == 12
      cOut := cOut + Chr(12)
   ELSEIF nC >= 32
      cOut := cOut + Chr( nC )
   ENDIF
NEXT

RETURN cOut
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION StripPCodes( cStr )
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
LOCAL nK, nUni

aCP862 := Array( 128 )

* Hebrew letters: 0x80..0x9A -> U+05D0..U+05EA
FOR nK := 0 TO 26
   nUni := 144 + nK
   aCP862[ nK + 1 ] := Chr( 215 ) + Chr( nUni )
NEXT

* 0x9B..0x9F (indices 28..32)
aCP862[ 28 ] := Chr(194) + Chr(162)
aCP862[ 29 ] := Chr(194) + Chr(163)
aCP862[ 30 ] := Chr(194) + Chr(165)
aCP862[ 31 ] := Chr(226) + Chr(130) + Chr(167)
aCP862[ 32 ] := Chr(198) + Chr(146)

* 0xA0..0xA9 (indices 33..42)
aCP862[ 33 ] := Chr(195) + Chr(161)
aCP862[ 34 ] := Chr(195) + Chr(173)
aCP862[ 35 ] := Chr(195) + Chr(179)
aCP862[ 36 ] := Chr(195) + Chr(186)
aCP862[ 37 ] := Chr(195) + Chr(177)
aCP862[ 38 ] := Chr(195) + Chr(145)
aCP862[ 39 ] := Chr(194) + Chr(170)
aCP862[ 40 ] := Chr(194) + Chr(186)
aCP862[ 41 ] := Chr(194) + Chr(191)
aCP862[ 42 ] := Chr(226) + Chr(140) + Chr(144)

* 0xAA..0xAF (indices 43..48)
aCP862[ 43 ] := Chr(194) + Chr(172)
aCP862[ 44 ] := Chr(194) + Chr(189)
aCP862[ 45 ] := Chr(194) + Chr(188)
aCP862[ 46 ] := Chr(194) + Chr(161)
aCP862[ 47 ] := Chr(194) + Chr(171)
aCP862[ 48 ] := Chr(194) + Chr(187)

* Box drawing: 0xB0..0xDF (indices 49..96)
aCP862[ 49 ] := Chr(226) + Chr(150) + Chr(145)
aCP862[ 50 ] := Chr(226) + Chr(150) + Chr(146)
aCP862[ 51 ] := Chr(226) + Chr(150) + Chr(147)
aCP862[ 52 ] := Chr(226) + Chr(148) + Chr(130)
aCP862[ 53 ] := Chr(226) + Chr(148) + Chr(164)
aCP862[ 54 ] := Chr(226) + Chr(149) + Chr(161)
aCP862[ 55 ] := Chr(226) + Chr(149) + Chr(162)
aCP862[ 56 ] := Chr(226) + Chr(149) + Chr(150)
aCP862[ 57 ] := Chr(226) + Chr(149) + Chr(149)
aCP862[ 58 ] := Chr(226) + Chr(149) + Chr(163)
aCP862[ 59 ] := Chr(226) + Chr(149) + Chr(145)
aCP862[ 60 ] := Chr(226) + Chr(149) + Chr(151)
aCP862[ 61 ] := Chr(226) + Chr(149) + Chr(157)
aCP862[ 62 ] := Chr(226) + Chr(149) + Chr(156)
aCP862[ 63 ] := Chr(226) + Chr(149) + Chr(155)
aCP862[ 64 ] := Chr(226) + Chr(148) + Chr(144)
aCP862[ 65 ] := Chr(226) + Chr(148) + Chr(148)
aCP862[ 66 ] := Chr(226) + Chr(148) + Chr(180)
aCP862[ 67 ] := Chr(226) + Chr(148) + Chr(172)
aCP862[ 68 ] := Chr(226) + Chr(148) + Chr(156)
aCP862[ 69 ] := Chr(226) + Chr(148) + Chr(128)
aCP862[ 70 ] := Chr(226) + Chr(148) + Chr(188)
aCP862[ 71 ] := Chr(226) + Chr(149) + Chr(158)
aCP862[ 72 ] := Chr(226) + Chr(149) + Chr(159)
aCP862[ 73 ] := Chr(226) + Chr(149) + Chr(154)
aCP862[ 74 ] := Chr(226) + Chr(149) + Chr(148)
aCP862[ 75 ] := Chr(226) + Chr(149) + Chr(169)
aCP862[ 76 ] := Chr(226) + Chr(149) + Chr(166)
aCP862[ 77 ] := Chr(226) + Chr(149) + Chr(160)
aCP862[ 78 ] := Chr(226) + Chr(149) + Chr(144)
aCP862[ 79 ] := Chr(226) + Chr(149) + Chr(172)
aCP862[ 80 ] := Chr(226) + Chr(149) + Chr(167)
aCP862[ 81 ] := Chr(226) + Chr(149) + Chr(168)
aCP862[ 82 ] := Chr(226) + Chr(149) + Chr(164)
aCP862[ 83 ] := Chr(226) + Chr(149) + Chr(165)
aCP862[ 84 ] := Chr(226) + Chr(149) + Chr(153)
aCP862[ 85 ] := Chr(226) + Chr(149) + Chr(152)
aCP862[ 86 ] := Chr(226) + Chr(149) + Chr(146)
aCP862[ 87 ] := Chr(226) + Chr(149) + Chr(147)
aCP862[ 88 ] := Chr(226) + Chr(149) + Chr(171)
aCP862[ 89 ] := Chr(226) + Chr(149) + Chr(170)
aCP862[ 90 ] := Chr(226) + Chr(148) + Chr(152)
aCP862[ 91 ] := Chr(226) + Chr(148) + Chr(140)
aCP862[ 92 ] := Chr(226) + Chr(150) + Chr(136)
aCP862[ 93 ] := Chr(226) + Chr(150) + Chr(132)
aCP862[ 94 ] := Chr(226) + Chr(150) + Chr(140)
aCP862[ 95 ] := Chr(226) + Chr(150) + Chr(144)
aCP862[ 96 ] := Chr(226) + Chr(150) + Chr(128)

* 0xE0..0xEF (indices 97..112)
aCP862[ 97 ]  := Chr(206) + Chr(177)
aCP862[ 98 ]  := Chr(195) + Chr(159)
aCP862[ 99 ]  := Chr(206) + Chr(147)
aCP862[ 100 ] := Chr(207) + Chr(128)
aCP862[ 101 ] := Chr(206) + Chr(163)
aCP862[ 102 ] := Chr(207) + Chr(131)
aCP862[ 103 ] := Chr(194) + Chr(181)
aCP862[ 104 ] := Chr(207) + Chr(132)
aCP862[ 105 ] := Chr(206) + Chr(166)
aCP862[ 106 ] := Chr(206) + Chr(152)
aCP862[ 107 ] := Chr(206) + Chr(169)
aCP862[ 108 ] := Chr(206) + Chr(180)
aCP862[ 109 ] := Chr(226) + Chr(136) + Chr(158)
aCP862[ 110 ] := Chr(207) + Chr(134)
aCP862[ 111 ] := Chr(206) + Chr(181)
aCP862[ 112 ] := Chr(226) + Chr(136) + Chr(169)

* 0xF0..0xFF (indices 113..128)
aCP862[ 113 ] := Chr(226) + Chr(137) + Chr(161)
aCP862[ 114 ] := Chr(194) + Chr(177)
aCP862[ 115 ] := Chr(226) + Chr(137) + Chr(165)
aCP862[ 116 ] := Chr(226) + Chr(137) + Chr(164)
aCP862[ 117 ] := Chr(226) + Chr(136) + Chr(171)
aCP862[ 118 ] := Chr(226) + Chr(136) + Chr(172)
aCP862[ 119 ] := Chr(195) + Chr(183)
aCP862[ 120 ] := Chr(226) + Chr(137) + Chr(136)
aCP862[ 121 ] := Chr(194) + Chr(176)
aCP862[ 122 ] := Chr(226) + Chr(136) + Chr(153)
aCP862[ 123 ] := Chr(194) + Chr(183)
aCP862[ 124 ] := Chr(226) + Chr(136) + Chr(154)
aCP862[ 125 ] := Chr(226) + Chr(129) + Chr(191)
aCP862[ 126 ] := Chr(194) + Chr(178)
aCP862[ 127 ] := Chr(226) + Chr(150) + Chr(160)
aCP862[ 128 ] := Chr(194) + Chr(160)

RETURN NIL
/*========================================================================*/
