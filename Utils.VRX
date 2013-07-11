/*:VRX         Main
*/
Main:
    signal on halt

    rc = 0
    PARSE ARG _function, _args

    SELECT
        WHEN _function == 'ConvertBytes'     THEN rc = ConvertBytes( _args )
        WHEN _function == 'ConvertSeconds'   THEN rc = ConvertSeconds( _args )
        WHEN _function == 'IsNumber'         THEN rc = IsNumber( _args )
        WHEN _function == 'IsPositiveNumber' THEN rc = IsPositiveNumber( _args )
        WHEN _function == 'PrettyNumber'     THEN rc = PrettyNumber( _args )
        WHEN _function == 'UploadSymbol'     THEN rc = CPSymbol('UP')
        WHEN _function == 'DownloadSymbol'   THEN rc = CPSymbol('DOWN')
        OTHERWISE NOP
    END

RETURN rc

/*:VRX         ConvertBytes
*/
ConvertBytes: PROCEDURE
    /* Convert a number of bytes into a suitable size string, using bytes, kB,
     * or MB as appropriate for the size.  
     */

    PARSE ARG _bytes

    IF IsNumber( _bytes ) == 0 THEN 
        RETURN _bytes

    SELECT
        WHEN _bytes <  1024    THEN sizestr = PrettyNumber( _bytes ) 'B'
        WHEN _bytes >= 1048576 THEN sizestr = PrettyNumber( FORMAT(_bytes/1048576,,1)) 'MB'
        OTHERWISE                   sizestr = PrettyNumber( FORMAT(_bytes/1024,,1)) 'kB'
    END

RETURN sizestr

/*:VRX         ConvertSeconds
*/
ConvertSeconds: PROCEDURE
    /* Convert a number of seconds into a suitable time string using seconds,
     * minutes, hours and days.
     */

    PARSE ARG seconds '.' .

    IF IsPositiveNumber( seconds ) == 0 THEN RETURN seconds

    IF VRMethod('Application', 'GetVar', 'sTime', '_ts') \= 1 THEN
       _ts = ':'
    IF VRMethod('Application', 'GetVar', 'sDay', '_ds1') \= 1 THEN
       _ds1 = 'day'
    IF VRMethod('Application', 'GetVar', 'sDays', '_ds2') \= 1 THEN
       _ds2 = 'days'

    _hour = seconds % 3600
    IF _hour > 24 THEN DO
        _day = _hour % 24
        _dhr = _hour // 24
        IF _day == 1 THEN
            _hour = _day _ds1 _dhr
        ELSE
            _hour = _day _ds2 _dhr
    END
    _tsec = seconds // 3600
    _min  = RIGHT( _tsec % 60, 2, '0')
    _sec  = RIGHT( _tsec // 60, 2, '0')
    time_str = _hour || _ts || _min || _ts || _sec

RETURN time_str

/*:VRX         CPSymbol
*/
CPSymbol: 
    ARG which

    _cp = SysQueryProcessCodepage()
    SELECT
        WHEN _cp == '932' THEN DO
            _up = 'ช'
            _dn = 'ซ'
        END
        WHEN _cp == '949' THEN DO
            _up = 'ก่'
            _dn = 'ก้'
        END
        WHEN _cp == '1381' THEN DO
            _up = 'กü'
            _dn = 'กý'
        END
        OTHERWISE DO
            _up = ''
            _dn = ''
        END
    END

    SELECT
        WHEN LEFT( which, 1 ) == 'U' THEN rv = _up
        WHEN LEFT( which, 1 ) == 'D' THEN rv = _dn
        OTHERWISE rv = ''
    END

RETURN rv

/*:VRX         Halt
*/
Halt:

exit

/*:VRX         IsNumber
*/
IsNumber: PROCEDURE
    /* Determine if the parameter is a valid decimal number.
     */
    PARSE ARG string
    IF ( VERIFY( string, '1234567890.') == 0 ) & ( STRIP( string, 'B', '.') \= '') THEN 
        RETURN 1
RETURN 0

/*:VRX         IsPositiveNumber
*/
IsPositiveNumber: PROCEDURE
    /* Determine if the parameter is a valid decimal number greater than zero.
     */
    PARSE ARG string
    IF ( VERIFY( string, '1234567890.') == 0 ) & ( STRIP( string, 'B', '.') \= '') & ( string > 0 ) THEN 
        RETURN 1
RETURN 0

/*:VRX         PrettyNumber
*/
PrettyNumber: PROCEDURE
    PARSE ARG number

    number = STRIP( number, 'B', '.')
    IF ( VERIFY( number, '1234567890.') == 0 ) THEN DO
        IF VRMethod('Application', 'GetVar', 'sThousand', '_ts') \= 1 THEN
            _ts = ' '
        IF VRMethod('Application', 'GetVar', 'sDecimal',  '_dp') \= 1 THEN
            _dp = '.'
        PARSE VALUE number WITH whole '.' decs
        pretty = strip( reverse( translate('abc'_ts'def'_ts'ghi'_ts'jkl'_ts'mno',,
                                 reverse(whole),,
                                 'abcdefghijklmno', _ts )), 'L', _ts )
        IF decs \= '' THEN pretty = pretty || _dp || decs
        number = pretty
    END

RETURN number

