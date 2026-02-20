/*========================================================================
 * RH2PARSE.PRG - RH2 Binary Report Template Parser
 *
 * Parses TVR (TripleVision Reporter) .RH2 binary files into Clipper arrays.
 * RH2 files are serialized Clipper arrays written by TVR's putarray() function.
 *
 * Binary format type codes:
 *   00 = NIL
 *   07 = STRING (2-byte LE length + data)
 *   0B = VERSION marker (1 byte version)
 *   0C = ARRAY start (2-byte LE element count)
 *   0E = DATE (4-byte LE Julian)
 *   0F = DOUBLE (width + dec + 8-byte IEEE754 LE)
 *   11 = INT8 (value + width)
 *   12 = INT16 no width (2-byte LE value)
 *   14 = INT16 (2-byte LE value + width)
 *   15 = INT32 (4-byte LE value + width)
 *   18 = NIL/EMPTY
 *   19 = BOOL TRUE
 *   1A = BOOL FALSE
 *========================================================================*/

#define RH2_NIL         0
#define RH2_STRING      7
#define RH2_VERSION    11    // 0x0B
#define RH2_ARRAY      12   // 0x0C
#define RH2_DATE       14   // 0x0E
#define RH2_DOUBLE     15   // 0x0F
#define RH2_INT8       17   // 0x11
#define RH2_INT16_NW   18   // 0x12
#define RH2_INT16      20   // 0x14
#define RH2_INT32      21   // 0x15
#define RH2_EMPTY      24   // 0x18
#define RH2_TRUE       25   // 0x19
#define RH2_FALSE      26   // 0x1A

STATIC nByteBuf      // single byte read buffer
STATIC cReadBuf      // multi-byte read buffer

/*========================================================================*/
FUNCTION RH2_LoadReport( cFile )
/*
 * Main entry point: parse an RH2 file and return the oRP array.
 * Returns NIL on error.
 *
 * putarray() serialization format: the top-level array is NOT wrapped
 * in an 0x0C array marker. Instead, each element of the oRP array is
 * written sequentially after the VERSION marker. We read them in a loop
 * and collect into the result array.
 */
LOCAL nHan, aResult, nType, xVal
LOCAL nFileSize, nCurPos

nHan := FOPEN( cFile, 0 )   // read-only
IF nHan < 0
   RETURN NIL
ENDIF

* get file size for EOF detection
nFileSize := FSEEK( nHan, 0, 2 )   // seek to end
FSEEK( nHan, 0, 0 )                // seek back to start

* initialize read buffers
nByteBuf := 0
cReadBuf := Space(8)

* read first value - should be VERSION marker (0x0B)
nType := RH2_ReadByte( nHan )
IF nType == RH2_VERSION
   * skip version byte
   RH2_ReadByte( nHan )
ELSE
   * no version marker - seek back to start
   FSEEK( nHan, 0, 0 )
ENDIF

* read all top-level elements sequentially into the oRP array
* putarray writes each oRP element as a separate value in the stream
aResult := {}
DO WHILE .T.
   nCurPos := FSEEK( nHan, 0, 1 )   // get current position
   IF nCurPos >= nFileSize
      EXIT
   ENDIF
   xVal := RH2_ReadValue( nHan )
   AAdd( aResult, xVal )
ENDDO

FCLOSE( nHan )
RETURN aResult
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_ReadValue( nHan )
/*
 * Read one value from the stream.
 * Dispatches by type code to appropriate reader.
 */
LOCAL nType, nLen, nVal, cStr
LOCAL aArr, nK
LOCAL nWidth, nDec
LOCAL cDblBuf, nJulian

nType := RH2_ReadByte( nHan )

DO CASE

   CASE nType == RH2_NIL .OR. nType == RH2_EMPTY
      * NIL value
      RETURN NIL

   CASE nType == RH2_TRUE
      * Boolean .T.
      RETURN .T.

   CASE nType == RH2_FALSE
      * Boolean .F.
      RETURN .F.

   CASE nType == RH2_STRING
      * String: 2-byte LE length + raw bytes
      nLen := RH2_ReadInt16LE( nHan )
      IF nLen == 0
         RETURN ""
      ENDIF
      cStr := Space( nLen )
      FREAD( nHan, @cStr, nLen )
      RETURN cStr

   CASE nType == RH2_INT8
      * 8-bit integer + width byte
      nVal   := RH2_ReadByte( nHan )
      nWidth := RH2_ReadByte( nHan )   // display width (ignored for value)
      RETURN nVal

   CASE nType == RH2_INT16_NW
      * 16-bit integer, no width byte
      nVal := RH2_ReadInt16LE( nHan )
      RETURN nVal

   CASE nType == RH2_INT16
      * 16-bit integer + width byte
      nVal   := RH2_ReadInt16LE( nHan )
      nWidth := RH2_ReadByte( nHan )
      RETURN nVal

   CASE nType == RH2_INT32
      * 32-bit integer + width byte
      nVal   := RH2_ReadInt32LE( nHan )
      nWidth := RH2_ReadByte( nHan )
      RETURN nVal

   CASE nType == RH2_DOUBLE
      * IEEE 754 double: width + dec + 8 bytes
      nWidth := RH2_ReadByte( nHan )
      nDec   := RH2_ReadByte( nHan )
      cDblBuf := Space(8)
      FREAD( nHan, @cDblBuf, 8 )
      * convert 8 bytes LE IEEE754 to Clipper numeric
      RETURN Bin2F( cDblBuf )

   CASE nType == RH2_DATE
      * Date: 4-byte LE Julian
      nJulian := RH2_ReadInt32LE( nHan )
      IF nJulian == 0
         RETURN CtoD("")   // empty date
      ENDIF
      RETURN Jul2Date( nJulian )

   CASE nType == RH2_ARRAY
      * Array: 2-byte LE count, then N elements
      nLen := RH2_ReadInt16LE( nHan )
      aArr := Array( nLen )
      FOR nK := 1 TO nLen
         aArr[ nK ] := RH2_ReadValue( nHan )
      NEXT
      RETURN aArr

   CASE nType == RH2_VERSION
      * Version marker inside data (shouldn't happen, but handle)
      RH2_ReadByte( nHan )   // skip version byte
      RETURN RH2_ReadValue( nHan )

   OTHERWISE
      * Unknown type code - return NIL and log
      RETURN NIL

ENDCASE

RETURN NIL
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_ReadByte( nHan )
/*
 * Read a single unsigned byte from file.
 */
LOCAL cBuf := Chr(0)
IF FREAD( nHan, @cBuf, 1 ) != 1
   RETURN -1
ENDIF
RETURN Asc( cBuf )
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_ReadInt16LE( nHan )
/*
 * Read 2-byte little-endian unsigned integer.
 */
LOCAL cBuf := Space(2)
FREAD( nHan, @cBuf, 2 )
RETURN Asc( SubStr(cBuf,1,1) ) + Asc( SubStr(cBuf,2,1) ) * 256
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_ReadInt32LE( nHan )
/*
 * Read 4-byte little-endian unsigned integer.
 */
LOCAL cBuf := Space(4)
LOCAL n0, n1, n2, n3
FREAD( nHan, @cBuf, 4 )
n0 := Asc( SubStr(cBuf,1,1) )
n1 := Asc( SubStr(cBuf,2,1) )
n2 := Asc( SubStr(cBuf,3,1) )
n3 := Asc( SubStr(cBuf,4,1) )
RETURN n0 + n1 * 256 + n2 * 65536 + n3 * 16777216
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION Bin2F( cBuf )
/*
 * Convert 8-byte IEEE 754 LE double to Clipper numeric.
 * Uses bit manipulation to extract sign, exponent, mantissa.
 */
LOCAL n0, n1, n2, n3, n4, n5, n6, n7
LOCAL nSign, nExp, nMant, nResult
LOCAL nK, nBit

* extract bytes (little-endian: byte 0 is LSB)
n0 := Asc( SubStr(cBuf,1,1) )
n1 := Asc( SubStr(cBuf,2,1) )
n2 := Asc( SubStr(cBuf,3,1) )
n3 := Asc( SubStr(cBuf,4,1) )
n4 := Asc( SubStr(cBuf,5,1) )
n5 := Asc( SubStr(cBuf,6,1) )
n6 := Asc( SubStr(cBuf,7,1) )
n7 := Asc( SubStr(cBuf,8,1) )

* sign bit: bit 7 of byte 7
nSign := Int( n7 / 128 )

* exponent: bits 6-0 of byte 7 + bit 7-4 of byte 6
nExp := ( n7 - nSign * 128 ) * 16 + Int( n6 / 16 )

* special cases
IF nExp == 0
   RETURN 0.0
ENDIF
IF nExp == 2047
   RETURN 0.0    // Inf or NaN - return 0
ENDIF

* mantissa: remaining 52 bits
* start with implicit leading 1
nMant := 1.0

* bits from byte 6 (lower 4 bits) = bits 51-48
nMant := nMant + ( n6 - Int(n6/16) * 16 ) / 16.0

* byte 5 = bits 47-40
nMant := nMant + n5 / 4096.0          // 16 * 256

* byte 4 = bits 39-32
nMant := nMant + n4 / 1048576.0       // 16 * 256 * 256

* byte 3 = bits 31-24
nMant := nMant + n3 / 268435456.0     // 16 * 256^3

* byte 2 = bits 23-16
nMant := nMant + n2 / 68719476736.0   // 16 * 256^4

* byte 1 = bits 15-8
nMant := nMant + n1 / 17592186044416.0  // 16 * 256^5

* byte 0 = bits 7-0
nMant := nMant + n0 / 4503599627370496.0  // 16 * 256^6 = 2^52

* result = (-1)^sign * 2^(exp-1023) * mantissa
nResult := nMant * ( 2.0 ** ( nExp - 1023 ) )

IF nSign == 1
   nResult := -nResult
ENDIF

RETURN nResult
/*========================================================================*/

/*========================================================================*/
STATIC FUNCTION Jul2Date( nJulian )
/*
 * Convert Julian Day Number to Clipper date.
 * Uses the algorithm from the Julian calendar.
 */
LOCAL nL, nN, nI, nJ, nD, nM, nY

IF nJulian <= 0
   RETURN CtoD("")
ENDIF

nL := nJulian + 68569
nN := Int( 4 * nL / 146097 )
nL := nL - Int( (146097 * nN + 3) / 4 )
nI := Int( 4000 * (nL + 1) / 1461001 )
nL := nL - Int( 1461 * nI / 4 ) + 31
nJ := Int( 80 * nL / 2447 )
nD := nL - Int( 2447 * nJ / 80 )
nL := Int( nJ / 11 )
nM := nJ + 2 - 12 * nL
nY := 100 * (nN - 49) + nI + nL

RETURN StoD( StrZero(nY,4) + StrZero(nM,2) + StrZero(nD,2) )
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_GetStr( xVal )
/*
 * Safe string extraction: returns empty string if not a string.
 */
IF ValType( xVal ) == "C"
   RETURN xVal
ENDIF
RETURN ""
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_GetNum( xVal )
/*
 * Safe numeric extraction: returns 0 if not a number.
 */
IF ValType( xVal ) == "N"
   RETURN xVal
ENDIF
RETURN 0
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_GetLog( xVal )
/*
 * Safe logical extraction: returns .F. if not logical.
 */
IF ValType( xVal ) == "L"
   RETURN xVal
ENDIF
RETURN .F.
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_GetArr( xVal )
/*
 * Safe array extraction: returns empty array if not an array.
 */
IF ValType( xVal ) == "A"
   RETURN xVal
ENDIF
RETURN {}
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_ArrLen( xVal )
/*
 * Safe array length: returns 0 if not an array.
 */
IF ValType( xVal ) == "A"
   RETURN Len( xVal )
ENDIF
RETURN 0
/*========================================================================*/

/*========================================================================*/
FUNCTION RH2_ArrVal( aArr, nIdx )
/*
 * Safe array element access: returns NIL if out of bounds.
 */
IF ValType( aArr ) == "A" .AND. nIdx >= 1 .AND. nIdx <= Len( aArr )
   RETURN aArr[ nIdx ]
ENDIF
RETURN NIL
/*========================================================================*/
