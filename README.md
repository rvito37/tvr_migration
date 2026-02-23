# TVR Migration - BMS Report System

Migration of BMS report system away from TVR (The Visual Reporter) dependency.

## Project Overview

BMS is a Clipper 5.2 / Harbour production management system. It uses TVR (The Visual Reporter v2.3a by Fieldston Consulting Group) for all report generation. TVR stores report templates as binary `.RH2` files using a proprietary `putarray()`/`getarray()` serialization format.

**Goal**: Eliminate TVR dependency by:
1. Parsing all 209 RH2 binary files into standard DBF tables (DONE)
2. Replacing `rpQuickLoad()` to read from DBF instead of binary RH2 (TODO)
3. Eventually replacing the report engine entirely with HTML output (TODO)

## Repository Structure

```
BMS_RH2_temp/
  source_prg/
    RH2PARSE.PRG     - Binary parser for RH2 files (putarray format)
    RH2TODBF.PRG     - Converter: parsed RH2 arrays -> 8 DBF tables
    RH2TEST.PRG      - Test harness, batch-converts all 209 RH2 files
    THEREPO.PRG      - TheReport class (main BMS report interface)
    PAGEOUT.PRG      - TVR page output handler (requires rptrans.ch)
    HTMLOUT.PRG      - Text-to-HTML converter (CP862->UTF8)
    PRNFACE.PRG      - Print UI / criteria selection screen
    PRNOUT.PRG       - Print output functions
    PRNCRIT.PRG      - Criteria display for reports
    PRINTERS.PRG     - Printer configuration
    PRNPRG.PRG       - Print program utilities
    REPHF.PRG        - Report header/footer
    REPSTUFF.PRG     - Report utility functions
    RPQC01V1.PRG     - Sample report definition (RACC01V1)
    RPQC01V1.HTM     - Sample HTML output
  RPT_DBF/
    RPT_MAIN.DBF     - 209 report headers (106 KB)
    RPT_FLD.DBF      - All field definitions (17.1 MB)
    RPT_LINE.DBF     - Line layout definitions (922 KB)
    RPT_LFLD.DBF     - Field placements within lines (1.3 MB)
    RPT_DB.DBF       - Database references (49 KB)
    RPT_REL.DBF      - Table relations (69 KB)
    RPT_SORT.DBF     - Sort definitions (361 B)
    RPT_LVL.DBF      - Group levels (108 KB)
    RH2TEST.LOG      - Conversion log (209 OK, 0 fail)
  hexdump.ps1        - PowerShell hex dump utility
```

## Build

Requires **Harbour 3.2.0dev** (located at `C:\hb32\`).

```bat
C:\hb32\bin\hbmk2 source_prg\RH2TEST.PRG source_prg\RH2PARSE.PRG source_prg\RH2TODBF.PRG -oRH2TEST.exe
RH2TEST.exe
```

Important build notes:
- Use `REQUEST HB_GT_CGI_DEFAULT` in Main() for non-interactive environments
- Harbour runtime errors cause silent hangs without custom error handler
- `Log()` function name conflicts with Harbour built-in `LOG()` math function - use `WriteLog()`
- `STATIC FUNCTION` not accessible across .PRG files - use `FUNCTION` for shared functions
- `@ row,col SAY` commands hang in non-interactive environments

## Key External Files (not in this repo)

| Path | Description |
|------|-------------|
| `C:\Users\AVXUser\BMS\` | Main BMS source code (all .PRG files) |
| `C:\Users\AVXUser\BMS\RH2\` | 209 original RH2 binary report files |
| `C:\Users\AVXUser\BMS\RPT_DBF\` | Copy of converted DBF tables for BMS use |
| `C:\Users\AVXUser\TVR\` | TVR library source and headers |
| `C:\Users\AVXUser\TVR\RP.CH` | TVR constants header (all #define for oRP array) |
| `C:\Users\AVXUser\TVR\RPTRANS.CH` | TVR #xtranslate macros (get/set pseudo-functions) |
| `C:\Users\AVXUser\TVR\SOURCE\RP2\` | TVR C source files |
| `C:\hb32\` | Harbour 3.2.0dev compiler |
| `C:\Users\AVXUser\BMS\analyze_rh2.pl` | Perl script for RH2 binary analysis |

## RH2 Binary Format (putarray serialization)

The `putarray()` C function serializes Clipper arrays to disk. **Critical discovery**: the top-level array is NOT wrapped in an `0x0C` array marker. Each element is written sequentially after a VERSION marker byte.

### Type Codes

| Byte | Type | Payload |
|------|------|---------|
| `0x00` | NIL | none |
| `0x07` | STRING | 2-byte LE length + data |
| `0x0B` | VERSION | 1-byte version number |
| `0x0C` | ARRAY | 2-byte LE element count, then elements |
| `0x0E` | DATE | 4-byte LE Julian day number |
| `0x0F` | DOUBLE | 1-byte width + 1-byte decimals + 8-byte IEEE754 |
| `0x11` | INT8 | 1-byte value + 1-byte width |
| `0x12` | INT16_NW | 2-byte LE (no width) |
| `0x14` | INT16 | 2-byte LE + 1-byte width |
| `0x15` | INT32 | 4-byte LE + 1-byte width |
| `0x18` | EMPTY_NIL | none |
| `0x19` | TRUE | none |
| `0x1A` | FALSE | none |

## oRP Array Structure (TVR Report Object)

The in-memory report is a 10-element array. All constants defined in `RP.CH`:

```
oRP[1]  = rpQUERY      - Query {text, block, description}
oRP[2]  = rpFIELDS     - Array of field objects (20 elements each)
oRP[3]  = rpREPORT     - Report settings (83 elements, indices 1-83)
oRP[4]  = rpDATABASE   - Array of database objects (16 elements each)
oRP[5]  = rpRUNTIME    - Runtime state (31+ elements)
oRP[6]  = rpLINES      - Array of line objects (33 elements each)
oRP[7]  = rpLEVELS     - Group levels {index, desc, level, flags...}
oRP[8]  = rpSORTS      - Sort definitions {rfo, order, desc}
oRP[9]  = rpUSERFUNCS  - User functions {line_out_block, tblock}
oRP[10] = rpFONTS      - Font definitions
```

### rpREPORT[3] Key Indices

| Index | Constant | Description |
|-------|----------|-------------|
| 22 | rpREPORT_PAGELEN | Page length in lines |
| 23 | rpREPORT_MARGIN_TOP | Top margin |
| 24 | rpREPORT_MARGIN_LEFT | Left margin |
| 25 | rpREPORT_MARGIN_BOTTOM | Bottom margin |
| 26 | rpREPORT_MARGIN_RIGHT | Right margin |
| 27 | rpREPORT_PRINTER | Printer name |
| 28 | rpREPORT_DEST | Destination (1=Printer, 2=File, 3=Display) |
| 29 | rpREPORT_HANDLE | Output file handle |
| 30 | rpREPORT_OUTFILE | Output filename |
| 35 | rpREPORT_LINES_PER_INCH | LPI |
| 36 | rpREPORT_CHARS_PER_INCH | CPI |
| 39 | rpREPORT_PAGE_ORIENT | 1=Portrait, 2=Landscape |
| 43 | rpREPORT_NAME | Report filename |
| 61 | rpREPORT_REC_WIDTH | Record width |
| 66 | rpREPORT_DATA_PATH | Data path |
| 67 | rpREPORT_INDEX_PATH | Index path |
| 68 | rpREPORT_SWAP_PATH | Swap path |
| 78 | rpREPORT_SHOW_COUNTER | Show record counter |
| 81 | rpREPORT_USE_FONTS | Use PCL fonts |

### rpFIELD Object (20 elements)

| Index | Constant | Description |
|-------|----------|-------------|
| 1 | rpTABLE_NAME | Table/alias name |
| 2 | rpFIELD_NAME | Field name |
| 3 | rpFIELD_TYPE | Type (C/N/D/L) |
| 4 | rpFIELD_LEN | Display width |
| 5 | rpFIELD_DEC | Decimal places |
| 6 | rpFIELD_LONGNAME | Long description |
| 7 | rpFIELD_BLOCK | Compiled code block |
| 8 | rpFIELD_TEXTBLOCK | Text of code block |
| 10 | rpFIELD_LEVEL | Group level |
| 11 | rpFIELD_PROCESS_TYPE | 0=None, 1=Running, 2=Preprocessed |
| 12 | rpFIELD_TOTAL_TYPE | 0=None, 1=Count..7=Variance |
| 15 | rpFIELD_TOTAL_ACC_FREQ | Accumulator reset frequency |

### rpLINE Object (33 elements)

| Index | Constant | Description |
|-------|----------|-------------|
| 1-14 | rpLFIELD_* | Parallel arrays for field placements |
| 16 | rpLINE_NEWPAGE | Force new page |
| 17 | rpPARENT_RP | Back-reference to oRP (set at runtime, NIL in file) |
| 18 | rpLINE_TYPE | 1=Title, 2=PgHdr, 3=Hdr, 4=Body, 5=Footer, 6=Summary, 7=PgFooter |
| 19 | rpLINE_LEVEL | Group level |
| 20 | rpLINE_ROW | Row position |
| 25 | rpLINE_FILTER | Filter code block |
| 26 | rpLINE_TFILTER | Filter text |
| 30 | rpLINE_HEIGHT | Line height |

### rpDATABASE Object (16 elements)

| Index | Constant | Description |
|-------|----------|-------------|
| 1 | rpDATABASE_TABLE | DBF file path |
| 2 | rpDATABASE_ALIAS | Alias name |
| 3 | rpDATABASE_INDEX | Index file path |
| 4 | rpDATABASE_KEYTBLOCK | Key text block |
| 8 | rpDATABASE_REL | Array of relation objects |
| 9 | rpDATABASE_ORDER_NAME | Order/tag name |
| 12 | rpDATABASE_RDDNAME | RDD driver name |
| 15 | rpDATABASE_OPEN_MODE | 1=Shared, 2=ReadOnly |

## DBF Table Schemas

All tables linked by `RPT_ID` (report filename without extension, e.g. "RACC01V1").

### RPT_MAIN - Report Headers (209 rows)

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| RPT_NAME | C | 40 | oRP[3][43] rpREPORT_NAME |
| PAGE_LEN | N | 4 | oRP[3][22] rpREPORT_PAGELEN |
| PAGE_ORI | N | 2 | oRP[3][39] rpREPORT_PAGE_ORIENT |
| MARG_TOP | N | 4 | oRP[3][23] rpREPORT_MARGIN_TOP |
| MARG_LEFT | N | 4 | oRP[3][24] rpREPORT_MARGIN_LEFT |
| MARG_BOT | N | 4 | oRP[3][25] rpREPORT_MARGIN_BOTTOM |
| MARG_RIGHT | N | 4 | oRP[3][26] rpREPORT_MARGIN_RIGHT |
| LPI | N | 2 | oRP[3][35] rpREPORT_LINES_PER_INCH |
| CPI | N | 2 | oRP[3][36] rpREPORT_CHARS_PER_INCH |
| REC_WIDTH | N | 4 | oRP[3][61] rpREPORT_REC_WIDTH |
| REC_ACROSS | N | 2 | oRP[3][31] rpREPORT_RECS_ACROSS |
| COPIES | N | 2 | oRP[3][32] rpREPORT_COPIES |
| QUERY_TXT | C | 200 | oRP[1][1] rpQUERY_TEXT |
| SCOPE_LO | C | 100 | oRP[3][48] rpREPORT_SCOPE_LOW |
| SCOPE_HI | C | 100 | oRP[3][49] rpREPORT_SCOPE_HIGH |
| SCOPE_TYP | C | 20 | oRP[3][50] rpREPORT_SCOPE_TYPE |

### RPT_FLD - Field Definitions

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| FLD_IDX | N | 4 | position in oRP[2] |
| TBL_NAME | C | 20 | oRP[2][n][1] rpTABLE_NAME |
| FLD_NAME | C | 20 | oRP[2][n][2] rpFIELD_NAME |
| FLD_TYPE | C | 1 | oRP[2][n][3] rpFIELD_TYPE |
| FLD_LEN | N | 4 | oRP[2][n][4] rpFIELD_LEN |
| FLD_DEC | N | 2 | oRP[2][n][5] rpFIELD_DEC |
| FLD_LONG | C | 40 | oRP[2][n][6] rpFIELD_LONGNAME |
| FLD_EXPR | C | 200 | oRP[2][n][8] rpFIELD_TEXTBLOCK |
| FLD_LEVEL | N | 4 | oRP[2][n][10] rpFIELD_LEVEL |
| FLD_PROC | N | 4 | oRP[2][n][11] rpFIELD_PROCESS_TYPE |
| FLD_TOTTYP | N | 4 | oRP[2][n][12] rpFIELD_TOTAL_TYPE |
| FLD_TOTACC | N | 4 | oRP[2][n][15] rpFIELD_TOTAL_ACC_FREQ |

### RPT_LINE - Line Layout

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| LINE_IDX | N | 4 | position in oRP[6] |
| LINE_TYPE | N | 2 | oRP[6][n][18] rpLINE_TYPE |
| LINE_LEVEL | N | 4 | oRP[6][n][19] rpLINE_LEVEL |
| LINE_ROW | N | 4 | oRP[6][n][20] rpLINE_ROW |
| LINE_FILT | C | 200 | oRP[6][n][26] rpLINE_TFILTER |
| LINE_TRIM | L | 1 | oRP[6][n][24] rpLINE_AUTOTRIM |
| LINE_COLOR | N | 4 | oRP[6][n][27] rpLINE_COLOR |
| LINE_NEWPG | L | 1 | oRP[6][n][16] rpLINE_NEWPAGE |
| LINE_HGT | N | 4 | oRP[6][n][30] rpLINE_HEIGHT |

### RPT_LFLD - Field Placement in Lines

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| LINE_IDX | N | 4 | line position in oRP[6] |
| POS_IDX | N | 4 | position within line's parallel arrays |
| COL_START | N | 4 | oRP[6][n][1][m] rpLFIELD_START |
| COL_END | N | 4 | oRP[6][n][2][m] rpLFIELD_END |
| FLD_IDX | N | 4 | oRP[6][n][3][m] rpLFIELD_INDEX |
| FLD_FMT | N | 4 | oRP[6][n][4][m] rpLFIELD_FORMAT |
| FLD_JUST | N | 2 | oRP[6][n][5][m] rpLFIELD_JUSTIFY |
| FLD_TRIM | L | 1 | oRP[6][n][9][m] rpLFIELD_AUTOTRIM |
| FLD_DEC | N | 4 | oRP[6][n][10][m] rpLFIELD_DEC |

### RPT_DB - Database References

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| DB_IDX | N | 4 | position in oRP[4] |
| DB_TABLE | C | 30 | oRP[4][n][1] rpDATABASE_TABLE |
| DB_ALIAS | C | 20 | oRP[4][n][2] rpDATABASE_ALIAS |
| DB_INDEX | C | 30 | oRP[4][n][3] rpDATABASE_INDEX |
| DB_ORDER | C | 30 | oRP[4][n][9] rpDATABASE_ORDER_NAME |
| DB_RDD | C | 12 | oRP[4][n][12] rpDATABASE_RDDNAME |

### RPT_REL - Relations

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| DB_IDX | N | 4 | parent database index in oRP[4] |
| REL_IDX | N | 4 | position in oRP[4][n][8] |
| REL_FROM | C | 20 | oRP[4][n][8][m][1] rpREL_FROMALIAS |
| REL_TO | C | 20 | oRP[4][n][8][m][2] rpREL_TOALIAS |
| REL_EXPR | C | 200 | oRP[4][n][8][m][4] rpREL_SEEKTEXT |
| REL_MATCH | C | 200 | oRP[4][n][8][m][6] rpREL_MATCHTEXT |
| REL_TYPE | N | 4 | oRP[4][n][8][m][7] rpREL_TYPE |

### RPT_SORT - Sort Definitions

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| SRT_IDX | N | 4 | position in oRP[8] |
| SRT_FLD | N | 4 | oRP[8][n][1] rpSORT_RFO |
| SRT_ORDER | C | 1 | oRP[8][n][2] rpSORT_ORDER |

### RPT_LVL - Group Levels

| Field | Type | Width | Maps to oRP |
|-------|------|-------|-------------|
| RPT_ID | C | 12 | key |
| LVL_IDX | N | 4 | position in oRP[7] |
| LVL_FLD | N | 4 | oRP[7][n][1] rpLEVEL_INDEX |
| LVL_DESC | C | 40 | oRP[7][n][2] rpLEVEL_DESC |
| LVL_BREAK | L | 1 | oRP[7][n][4] rpLEVEL_ALLOW_BREAK |
| LVL_PGRST | L | 1 | oRP[7][n][5] rpLEVEL_PAGE_RESET |
| LVL_SWPHDR | L | 1 | oRP[7][n][6] rpLEVEL_SWAP_HEADER |
| LVL_SWPFTR | L | 1 | oRP[7][n][7] rpLEVEL_SWAP_FOOTER |
| LVL_RPTHDR | L | 1 | oRP[7][n][8] rpLEVEL_REPEAT_HEADER |

## BMS TVR Integration Architecture

### Call Flow

```
User -> RPQC##V1.PRG -> TheReport:EXEC() -> TheReport:Print()
                                          -> TheReport:SpreadSheet()
                                          -> TheReport:Query()

TheReport:Print() does:
  1. rpNew()           - create report object (oRP = rpREPORT_OBJECT)
  2. rpDataPath()      - set data/index/swap paths
  3. rpQuickLoad()     - load RH2 binary via getarray() -> oRP
  4. rpUseFonts()      - disable PCL fonts
  5. rpGetRDO()        - get database object from oRP[4]
  6. rpDBTable()       - override data source path
  7. rpMyDBOpen()      - open database
  8. rpDBIndex()       - set index
  9. rpDestination()   - set output target (1=printer, 2=file, 3=display)
  10. rpGenReport()    - GENERATE REPORT (GEN.PRG, ~1000 lines)
      -> rpRunInit()   - init runtime, open output
      -> rpDBInit()    - position databases
      -> loop: rpSkip() -> evaluate fields -> rpPageOut(aPage)
  11. rpKillSorts()    - cleanup sort files
  12. rpCloseData()    - close databases
```

### Key TVR Source Files in BMS

| File | Functions | Description |
|------|-----------|-------------|
| `BMS\RPSAVE.PRG` | rpQuickLoad(), rpQuickSave() | Load/save RH2 files. Uses `getarray()`/`putarray()` C functions |
| `BMS\GEN.PRG` | rpGenReport() | Core report generation engine (~1000 lines) |
| `BMS\RUNINIT.PRG` | rpRunInit() | Runtime init, destination setup, file handle creation |
| `BMS\DATABASE.PRG` | rpDBInit(), rpSkip(), rpSort() | Database scanning, sorting, relations |
| `BMS\PAGEOUT.PRG` | rpPageOut(), rpPrintReset() | Page output to printer/file/display |
| `BMS\INITPCOD.PRG` | rpInitPCodes(), rpUseFonts() | Printer code init (PCL/HP/Epson) |
| `BMS\RPDBOPEN.PRG` | rpMyDBOpen(), rpDBOpen() | Database file opening |
| `BMS\DBINDEX.PRG` | rpDBIndex() | Index management |
| `BMS\RESETPOS.PRG` | rpResetPos() | Record pointer management |
| `BMS\THEREPO.PRG` | TheReport class | Main BMS report orchestrator |
| `BMS\RPSRTNUM.PRG` | rpSortNum() | Sort number handling |

### TVR C Library Functions (binary, no source available for these)

- `getarray(nHandle)` - Deserialize RH2 binary to Clipper array (in TVR .LIB)
- `putarray(nHandle, aArray)` - Serialize Clipper array to RH2 binary (in TVR .LIB)

### 19 BMS Files That Reference TVR

THEREPO.PRG, RPDBOPEN.PRG, XTABREP.PRG, SCH_REQM.PRG, SCH_ORDM.PRG,
RPQC14V1.PRG, RPQC10V1.PRG, RMRK08V2.PRG, QMRK37V1.PRG,
DBINDEX.PRG, DATABASE.PRG, GEN.PRG, RUNINIT.PRG,
XTAB.PRG, XTAB2.PRG, INITPCOD.PRG, RPSAVE.PRG,
SHREPORT.PRG, PAGEOUT.PRG

## Phase 1: RH2 to DBF Conversion (COMPLETED)

All 209 RH2 files successfully converted to 8 DBF tables. Zero failures.

Key discoveries during Phase 1:
- `putarray()` does NOT wrap the top-level array in a `0x0C` array marker
- Each oRP element is written sequentially after a VERSION byte
- The parser must loop reading values until EOF (not single `RH2_ReadValue()`)
- Harbour runtime errors cause silent hangs without custom error handler + `REQUEST HB_GT_CGI_DEFAULT`
- Numeric fields wider than N,2 needed for some reports (values > 99)

## Phase 2: Replace rpQuickLoad (TODO)

**Strategy**: Modify `rpQuickLoad()` in `RPSAVE.PRG` to read from DBF tables instead of calling `getarray()` on a binary RH2 file.

The new function would:
1. Extract RPT_ID from the filename
2. Read RPT_MAIN for report settings -> populate oRP[3] (rpREPORT, 83-element array)
3. Read RPT_FLD for field definitions -> populate oRP[2] (rpFIELDS, array of 20-element objects)
4. Read RPT_DB for database refs -> populate oRP[4] (rpDATABASE, array of 16-element objects)
5. Read RPT_LINE + RPT_LFLD for line layout -> populate oRP[6] (rpLINES, array of 33-element objects with parallel sub-arrays)
6. Read RPT_REL for relations -> populate oRP[4][n][8] (relation sub-arrays)
7. Read RPT_SORT for sorts -> populate oRP[8] (rpSORTS)
8. Read RPT_LVL for levels -> populate oRP[7] (rpLEVELS)
9. Init oRP[1] (rpQUERY), oRP[5] (rpRUNTIME), oRP[9] (rpUSERFUNCS), oRP[10] (rpFONTS) with defaults from rpREPORT_OBJECT

This eliminates the `getarray()` C function dependency entirely. All other TVR functions (rpGenReport, rpPageOut, etc.) continue working unchanged since they only interact with the in-memory oRP array.

## Phase 3: HTML Report Engine (FUTURE)

Replace `rpGenReport()` + `rpPageOut()` with direct HTML generation from DBF tables, eliminating the entire TVR runtime.

## Technical Notes

- Language: xBase (Clipper 5.2 / Harbour 3.2.0dev)
- Database: DBF/CDX (DBFCDXAX driver)
- Report engine: TVR v2.3a (The Visual Reporter by Fieldston Consulting Group, (C) 1992-1996 Richard Horwitz)
- Encoding: CP862 (Hebrew DOS) for field values, Windows-1255 for some comments
- All reports output to monospace format (typically 80 or 120 columns, landscape)
- `rp.ch` and `rptrans.ch` are in `C:\Users\AVXUser\TVR\` (not in BMS directory)
- Some RPQC##V1.PRG files define hardcoded reports via `cbBuildRep` code block instead of using RH2 files
