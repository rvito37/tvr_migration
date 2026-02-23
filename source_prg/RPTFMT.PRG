/*========================================================================
 * RPTFMT.PRG - Report field formatting utilities
 *
 * Replaces TVR's FORMATS.PRG + C utility functions (untrim, ljust, etc.)
 * All formatting that rpMakeNew/MAKEGROUP did is replicated here.
 *
 * Target: Clipper 5.3
 *
 * Author: Auto-generated for BMS TVR Migration
 *========================================================================*/

/*------------------------------------------------------------------------
 * Format type constants (matching TVR FORMATS.PRG values)
 * These are the FLD_FMT values stored in RPT_LFLD
 *------------------------------------------------------------------------*/
#DEFINE FMT_NONE              1

* Character formats
#DEFINE FMT_C_LEFT            2
#DEFINE FMT_C_CENTER          3
#DEFINE FMT_C_RIGHT           4
#DEFINE FMT_C_WORDWRAP        5
#DEFINE FMT_C_MAILMERGE       6
#DEFINE FMT_C_CAPFIRST        7
#DEFINE FMT_C_UPPER           8
#DEFINE FMT_C_LOWER           9
#DEFINE FMT_C_CENTER_UPPER   10

* Date formats
#DEFINE FMT_D_FULL_MDY        2
#DEFINE FMT_D_FULL_DMY        3
#DEFINE FMT_D_FULL_MY         4
#DEFINE FMT_D_FULL_DM         5
#DEFINE FMT_D_SHORT_MDY       6
#DEFINE FMT_D_SHORT_DM        7
#DEFINE FMT_D_SHORT_MY        8
#DEFINE FMT_D_DTOS            9
#DEFINE FMT_D_CMONTH         10
#DEFINE FMT_D_SHORT_DMY      11

* Numeric formats
#DEFINE FMT_N_FIXED            2
#DEFINE FMT_N_SCIENTIFIC       3
#DEFINE FMT_N_CURRENCY         4
#DEFINE FMT_N_COMMA            5
#DEFINE FMT_N_GENERAL          6
#DEFINE FMT_N_PERCENT          7
#DEFINE FMT_N_PLUS_MINUS       8
#DEFINE FMT_N_LEADSTAR         9

* Logical formats
#DEFINE FMT_L_YN               2
#DEFINE FMT_L_TRUE_FALSE       3
#DEFINE FMT_L_YES_NO           4
#DEFINE FMT_L_DOT_YN           5

* Justification constants
#DEFINE JUST_DEFAULT   0
#DEFINE JUST_LEFT      1
#DEFINE JUST_RIGHT     2
#DEFINE JUST_CENTER    3
#DEFINE JUST_FULL      4


/*========================================================================*/
FUNCTION RptFmtField( xValue, cType, nLen, nDec, nFmt, nJust )
/*
 * Format a field value for report output.
 *
 * Parameters:
 *   xValue - The raw value (any type)
 *   cType  - Field type: "C", "N", "D", "L"
 *   nLen   - Display length
 *   nDec   - Number of decimal places (for N fields)
 *   nFmt   - Format number (1=None, 2..N = type-specific)
 *   nJust  - Justification (0=default, 1=left, 2=right, 3=center, 4=full)
 *
 * Returns: Formatted string of exactly nLen characters
 */
LOCAL cResult := ""

IF nLen == NIL .OR. nLen <= 0
   nLen := 10
ENDIF
IF nFmt == NIL
   nFmt := FMT_NONE
ENDIF
IF nDec == NIL
   nDec := 0
ENDIF
IF nJust == NIL
   nJust := JUST_DEFAULT
ENDIF

* format based on type
DO CASE
   CASE cType == "C" .OR. cType == "M"
      cResult := FmtChar( xValue, nLen, nFmt )

   CASE cType == "N"
      cResult := FmtNum( xValue, nLen, nDec, nFmt )

   CASE cType == "D"
      cResult := FmtDate( xValue, nLen, nFmt )

   CASE cType == "L"
      cResult := FmtLog( xValue, nLen, nFmt )

   OTHERWISE
      * fallback: treat as char
      IF ValType( xValue ) == "C"
         cResult := PadR( xValue, nLen )
      ELSE
         cResult := PadR( "", nLen )
      ENDIF
ENDCASE

* apply justification override (if not already handled by format)
IF nJust != JUST_DEFAULT
   DO CASE
      CASE nJust == JUST_LEFT
         cResult := PadR( LTrim( cResult ), nLen )
      CASE nJust == JUST_RIGHT
         cResult := PadL( AllTrim( cResult ), nLen )
      CASE nJust == JUST_CENTER
         cResult := RptStrCenter( AllTrim( cResult ), nLen )
      CASE nJust == JUST_FULL
         cResult := RptStrFull( cResult, nLen )
   ENDCASE
ENDIF

RETURN cResult
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION FmtChar( xValue, nLen, nFmt )
/*
 * Format a character value.
 */
LOCAL cVal

IF ValType( xValue ) != "C"
   cVal := Space( nLen )
ELSE
   cVal := xValue
ENDIF

DO CASE
   CASE nFmt == FMT_NONE
      RETURN PadR( Left( cVal, nLen ), nLen )

   CASE nFmt == FMT_C_LEFT
      RETURN PadR( LTrim( cVal ), nLen )

   CASE nFmt == FMT_C_CENTER
      RETURN RptStrCenter( cVal, nLen )

   CASE nFmt == FMT_C_RIGHT
      RETURN PadL( RTrim( cVal ), nLen )

   CASE nFmt == FMT_C_CAPFIRST
      RETURN PadR( RptCapFirst( cVal ), nLen )

   CASE nFmt == FMT_C_UPPER
      RETURN PadR( Upper( cVal ), nLen )

   CASE nFmt == FMT_C_LOWER
      RETURN PadR( Lower( cVal ), nLen )

   CASE nFmt == FMT_C_CENTER_UPPER
      RETURN RptStrCenter( Upper( cVal ), nLen )

   CASE nFmt == FMT_C_WORDWRAP
      * wordwrap: just return first nLen chars for now
      * (full memo wrap handled in report generator)
      RETURN PadR( Left( cVal, nLen ), nLen )

   CASE nFmt == FMT_C_MAILMERGE
      * mail merge: same as wordwrap for basic case
      RETURN PadR( Left( cVal, nLen ), nLen )

   OTHERWISE
      RETURN PadR( Left( cVal, nLen ), nLen )
ENDCASE

RETURN PadR( Left( cVal, nLen ), nLen )
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION FmtNum( xValue, nLen, nDec, nFmt )
/*
 * Format a numeric value.
 */
LOCAL cVal, cTmp

IF ValType( xValue ) != "N"
   IF ValType( xValue ) == "C"
      RETURN PadR( xValue, nLen )
   ENDIF
   RETURN Space( nLen )
ENDIF

DO CASE
   CASE nFmt == FMT_NONE .OR. nFmt == FMT_N_GENERAL
      RETURN Str( xValue, nLen, nDec )

   CASE nFmt == FMT_N_FIXED .OR. nFmt == FMT_N_SCIENTIFIC
      RETURN Str( xValue, nLen, nDec )

   CASE nFmt == FMT_N_CURRENCY
      cTmp := LTrim( Transform( xValue, Replicate( "9", 12 ) + ;
              IIF( nDec > 0, "." + Replicate( "9", nDec ), "" ) ) )
      cTmp := RptAddCommas( cTmp )
      cVal := "$" + cTmp
      RETURN PadL( cVal, nLen )

   CASE nFmt == FMT_N_COMMA
      cTmp := LTrim( Transform( xValue, Replicate( "9", 12 ) + ;
              IIF( nDec > 0, "." + Replicate( "9", nDec ), "" ) ) )
      cTmp := RptAddCommas( cTmp )
      RETURN PadL( cTmp, nLen )

   CASE nFmt == FMT_N_PERCENT
      cTmp := LTrim( Str( xValue * 100, nLen, nDec ) ) + "%"
      RETURN PadL( cTmp, nLen )

   CASE nFmt == FMT_N_PLUS_MINUS
      cTmp := IIF( xValue >= 0, "+", "-" ) + LTrim( Str( Abs( xValue ), nLen, nDec ) )
      RETURN PadL( cTmp, nLen )

   CASE nFmt == FMT_N_LEADSTAR
      cTmp := LTrim( Transform( xValue, Replicate( "9", 12 ) + ;
              IIF( nDec > 0, "." + Replicate( "9", nDec ), "" ) ) )
      cTmp := RptAddCommas( cTmp )
      cVal := PadL( cTmp, nLen )
      RETURN StrTran( cVal, " ", "*" )

   OTHERWISE
      RETURN Str( xValue, nLen, nDec )
ENDCASE

RETURN Str( xValue, nLen, nDec )
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION FmtDate( xValue, nLen, nFmt )
/*
 * Format a date value.
 */
LOCAL cVal

IF ValType( xValue ) != "D"
   IF ValType( xValue ) == "C"
      RETURN PadR( xValue, nLen )
   ENDIF
   RETURN Space( nLen )
ENDIF

IF Empty( xValue )
   RETURN Space( nLen )
ENDIF

DO CASE
   CASE nFmt == FMT_NONE
      RETURN PadR( DToC( xValue ), nLen )

   CASE nFmt == FMT_D_FULL_MDY
      cVal := CMonth( xValue ) + " " + LTrim( Str( Day( xValue ), 2 ) ) + ;
              ", " + Str( Year( xValue ), 4 )
      RETURN PadR( cVal, nLen )

   CASE nFmt == FMT_D_FULL_DMY
      cVal := LTrim( Str( Day( xValue ), 2 ) ) + " " + CMonth( xValue ) + ;
              " " + Str( Year( xValue ), 4 )
      RETURN PadR( cVal, nLen )

   CASE nFmt == FMT_D_FULL_MY
      cVal := CMonth( xValue ) + " " + Str( Year( xValue ), 4 )
      RETURN PadR( LTrim( cVal ), nLen )

   CASE nFmt == FMT_D_FULL_DM
      cVal := LTrim( Str( Day( xValue ), 2 ) ) + " " + CMonth( xValue )
      RETURN PadR( LTrim( cVal ), nLen )

   CASE nFmt == FMT_D_SHORT_MDY
      cVal := Left( CMonth( xValue ), 3 ) + "-" + ;
              PadL( LTrim( Str( Day( xValue ), 2 ) ), 2 ) + "-" + ;
              Right( Str( Year( xValue ), 4 ), 2 )
      RETURN PadR( LTrim( cVal ), nLen )

   CASE nFmt == FMT_D_SHORT_DM
      cVal := LTrim( Str( Day( xValue ), 2 ) ) + "-" + ;
              Left( CMonth( xValue ), 3 )
      RETURN PadR( LTrim( cVal ), nLen )

   CASE nFmt == FMT_D_SHORT_MY
      cVal := Left( CMonth( xValue ), 3 ) + "-" + ;
              Right( Str( Year( xValue ), 4 ), 2 )
      RETURN PadR( cVal, nLen )

   CASE nFmt == FMT_D_DTOS
      RETURN PadR( DToS( xValue ), nLen )

   CASE nFmt == FMT_D_CMONTH
      RETURN PadR( CMonth( xValue ), nLen )

   CASE nFmt == FMT_D_SHORT_DMY
      cVal := LTrim( Str( Day( xValue ), 2 ) ) + "-" + ;
              Left( CMonth( xValue ), 3 ) + "-" + ;
              Right( Str( Year( xValue ), 4 ), 2 )
      RETURN PadR( LTrim( cVal ), nLen )

   OTHERWISE
      RETURN PadR( DToC( xValue ), nLen )
ENDCASE

RETURN PadR( DToC( xValue ), nLen )
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION FmtLog( xValue, nLen, nFmt )
/*
 * Format a logical value.
 */
LOCAL cVal

IF ValType( xValue ) != "L"
   IF ValType( xValue ) == "C"
      RETURN PadR( xValue, nLen )
   ENDIF
   RETURN Space( nLen )
ENDIF

DO CASE
   CASE nFmt == FMT_NONE
      cVal := IIF( xValue, "T", "F" )

   CASE nFmt == FMT_L_YN
      cVal := IIF( xValue, "Y", "N" )

   CASE nFmt == FMT_L_TRUE_FALSE
      cVal := IIF( xValue, "True", "False" )

   CASE nFmt == FMT_L_YES_NO
      cVal := IIF( xValue, "Yes", "No" )

   CASE nFmt == FMT_L_DOT_YN
      cVal := IIF( xValue, ".T.", ".F." )

   OTHERWISE
      cVal := IIF( xValue, "T", "F" )
ENDCASE

RETURN PadR( cVal, nLen )
/*========================================================================*/


/*========================================================================*/
FUNCTION RptStrCenter( cText, nWidth )
/*
 * Center a string within nWidth characters.
 * Replaces TVR's strcenter() / center().
 */
LOCAL cTrim, nPad

IF ValType( cText ) != "C"
   RETURN Space( nWidth )
ENDIF

cTrim := AllTrim( cText )
IF Len( cTrim ) >= nWidth
   RETURN Left( cTrim, nWidth )
ENDIF

nPad := Int( ( nWidth - Len( cTrim ) ) / 2 )
RETURN Space( nPad ) + cTrim + Space( nWidth - nPad - Len( cTrim ) )
/*========================================================================*/


/*========================================================================*/
FUNCTION RptStrFull( cText, nWidth )
/*
 * Full-justify text within nWidth characters.
 * Distributes extra spaces between words.
 * Replaces TVR's tokenjustify().
 */
LOCAL aWords, nK, nSpaces, nExtra, nGaps, cResult

IF ValType( cText ) != "C" .OR. Empty( cText )
   RETURN Space( nWidth )
ENDIF

* split into words
aWords := RptSplitWords( AllTrim( cText ) )

IF Len( aWords ) <= 1
   RETURN PadR( AllTrim( cText ), nWidth )
ENDIF

* calculate total space needed between words
nSpaces := nWidth
FOR nK := 1 TO Len( aWords )
   nSpaces -= Len( aWords[ nK ] )
NEXT

nGaps := Len( aWords ) - 1
IF nGaps <= 0 .OR. nSpaces <= 0
   RETURN PadR( AllTrim( cText ), nWidth )
ENDIF

* distribute spaces evenly
cResult := aWords[ 1 ]
FOR nK := 2 TO Len( aWords )
   nExtra := Int( nSpaces / ( Len( aWords ) - nK + 1 ) )
   cResult := cResult + Space( nExtra )
   nSpaces -= nExtra
   cResult := cResult + aWords[ nK ]
NEXT

RETURN PadR( cResult, nWidth )
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptSplitWords( cText )
/*
 * Split text into array of words (separated by spaces).
 */
LOCAL aWords := {}
LOCAL cWord := ""
LOCAL nK, cCh

FOR nK := 1 TO Len( cText )
   cCh := SubStr( cText, nK, 1 )
   IF cCh == " "
      IF !Empty( cWord )
         AAdd( aWords, cWord )
         cWord := ""
      ENDIF
   ELSE
      cWord := cWord + cCh
   ENDIF
NEXT

IF !Empty( cWord )
   AAdd( aWords, cWord )
ENDIF

RETURN aWords
/*========================================================================*/


/*========================================================================*/
FUNCTION RptCapFirst( cText )
/*
 * Capitalize the first letter of each word.
 * Replaces TVR's capfirst().
 */
LOCAL cResult := Lower( cText )
LOCAL nK
LOCAL lNextUpper := .T.

FOR nK := 1 TO Len( cResult )
   IF SubStr( cResult, nK, 1 ) == " "
      lNextUpper := .T.
   ELSEIF lNextUpper
      cResult := Left( cResult, nK - 1 ) + Upper( SubStr( cResult, nK, 1 ) ) + SubStr( cResult, nK + 1 )
      lNextUpper := .F.
   ENDIF
NEXT

RETURN cResult
/*========================================================================*/


/*========================================================================*/
FUNCTION RptAddCommas( cNumStr )
/*
 * Add thousand separators to a numeric string.
 * Input: "1234567.89" -> "1,234,567.89"
 */
LOCAL cInt, cFrac, nDotPos, nK, cResult

cNumStr := AllTrim( cNumStr )

* handle negative
IF Left( cNumStr, 1 ) == "-"
   RETURN "-" + RptAddCommas( SubStr( cNumStr, 2 ) )
ENDIF

* split integer and fraction
nDotPos := At( ".", cNumStr )
IF nDotPos > 0
   cInt  := Left( cNumStr, nDotPos - 1 )
   cFrac := SubStr( cNumStr, nDotPos )  // includes the dot
ELSE
   cInt  := cNumStr
   cFrac := ""
ENDIF

* add commas from right
cResult := ""
FOR nK := Len( cInt ) TO 1 STEP -1
   cResult := SubStr( cInt, nK, 1 ) + cResult
   IF ( Len( cInt ) - nK + 1 ) % 3 == 0 .AND. nK > 1
      cResult := "," + cResult
   ENDIF
NEXT

RETURN cResult + cFrac
/*========================================================================*/


/*========================================================================*/
FUNCTION RptBuildLine( nLineLen, nIndent, aLFlds, aValues )
/*
 * Build a single output line by placing formatted field values
 * at their column positions.
 *
 * Parameters:
 *   nLineLen - Total line width
 *   nIndent  - Left margin indent
 *   aLFlds   - Array of line-field placement sub-arrays
 *   aValues  - Array of formatted string values (parallel to aLFlds)
 *
 * Returns: A string of exactly nLineLen characters
 *
 * This replaces what MAKEGROUP() did in the TVR C library.
 */
LOCAL cLine := Space( nLineLen )
LOCAL nK, nStart, nEnd, nWidth, cVal

FOR nK := 1 TO Len( aLFlds )

   nStart := aLFlds[ nK ][ 3 ] + nIndent   // RLF_COL_S + indent
   nEnd   := aLFlds[ nK ][ 4 ] + nIndent   // RLF_COL_E + indent
   nWidth := nEnd - nStart + 1

   IF nK <= Len( aValues ) .AND. aValues[ nK ] != NIL
      cVal := aValues[ nK ]
      * ensure value fits in column width
      IF Len( cVal ) > nWidth
         cVal := Left( cVal, nWidth )
      ELSEIF Len( cVal ) < nWidth
         cVal := PadR( cVal, nWidth )
      ENDIF
   ELSE
      cVal := Space( nWidth )
   ENDIF

   * place value into line at correct position
   IF nStart >= 1 .AND. nStart <= nLineLen
      IF nStart + nWidth - 1 > nLineLen
         nWidth := nLineLen - nStart + 1
         cVal := Left( cVal, nWidth )
      ENDIF
      cLine := Left( cLine, nStart - 1 ) + cVal + ;
               SubStr( cLine, nStart + nWidth )
   ENDIF

NEXT

RETURN cLine
/*========================================================================*/


/*========================================================================*/
FUNCTION RptFmtInit()
/*
 * Initialize the format system (no-op in our implementation,
 * kept for API compatibility).
 */
RETURN NIL
/*========================================================================*/
