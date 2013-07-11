/*:VRX         Main
*/
/*  Main
*/
Main:
/*  Process the arguments.
    Get the parent window.
*/
    parse source . calledAs .
    parent = ""
    argCount = arg()
    argOff = 0
    if( calledAs \= "COMMAND" )then do
        if argCount >= 1 then do
            parent = arg(1)
            argCount = argCount - 1
            argOff = 1
        end
    end; else do
        call VROptions 'ImplicitNames'
        call VROptions 'NoEchoQuit'
    end
    InitArgs.0 = argCount
    if( argCount > 0 )then do i = 1 to argCount
        InitArgs.i = arg( i + argOff )
    end
    drop calledAs argCount argOff

/*  Load the windows
*/
    call VRInit
    parse source . . spec
    _VREPrimaryWindowPath = ,
        VRParseFileName( spec, "dpn" ) || ".VRW"
    _VREPrimaryWindow = ,
        VRLoad( parent, _VREPrimaryWindowPath )
    drop parent spec
    if( _VREPrimaryWindow == "" )then do
        call VRMessage "", "Cannot load window:" VRError(), ,
            "Error!"
        _VREReturnValue = 32000
        signal _VRELeaveMain
    end

/*  Process events
*/
    call Init
    signal on halt
    do while( \ VRGet( _VREPrimaryWindow, "Shutdown" ) )
        _VREEvent = VREvent()
        interpret _VREEvent
    end
_VREHalt:
    _VREReturnValue = Fini()
    call VRDestroy _VREPrimaryWindow
_VRELeaveMain:
    call VRFini
exit _VREReturnValue

VRLoadSecondary:
    __vrlsWait = abbrev( 'WAIT', translate(arg(2)), 1 )
    if __vrlsWait then do
        call VRFlush
    end
    __vrlsHWnd = VRLoad( VRWindow(), VRWindowPath(), arg(1) )
    if __vrlsHWnd = '' then signal __vrlsDone
    if __vrlsWait \= 1 then signal __vrlsDone
    call VRSet __vrlsHWnd, 'WindowMode', 'Modal'
    __vrlsTmp = __vrlsWindows.0
    if( DataType(__vrlsTmp) \= 'NUM' ) then do
        __vrlsTmp = 1
    end
    else do
        __vrlsTmp = __vrlsTmp + 1
    end
    __vrlsWindows.__vrlsTmp = VRWindow( __vrlsHWnd )
    __vrlsWindows.0 = __vrlsTmp
    do while( VRIsValidObject( VRWindow() ) = 1 )
        __vrlsEvent = VREvent()
        interpret __vrlsEvent
    end
    __vrlsTmp = __vrlsWindows.0
    __vrlsWindows.0 = __vrlsTmp - 1
    call VRWindow __vrlsWindows.__vrlsTmp
    __vrlsHWnd = ''
__vrlsDone:
return __vrlsHWnd

/*:VRX         _NoValue
*/
_NoValue:
    SAY 'Reference to non-initialized variable on line:' sigl
    SAY sigl '***' STRIP( SOURCELINE( sigl ))
EXIT sigl

/*:VRX         AddExistingTorrents
*/
AddExistingTorrents: PROCEDURE EXPOSE global. config.
    PARSE ARG torrents_dir

    /* Scan the specified torrent directory for any torrents which are
     * currently being managed.  Called on program startup.
     */

    ok = SysFileTree( torrents_dir'\*', 'torfiles.', 'FO', '*--*-')
    IF ok <> 0 THEN RETURN

    DO i = 1 TO torfiles.0

        IF TRANSLATE( RIGHT( torfiles.i, 3 )) == '.BF' THEN ITERATE
        IF IsTorrent( torfiles.i ) == 0 THEN ITERATE
        statustext = ''

        /* See if the torrent file has a 'Seeding' EA, and use that to make sure
         * it's in the correct directory.
         */
        seeding_ea = 0
        IF SysGetEA( torfiles.i, 'PMFACT.Seeding', 'eadata') == 0 THEN
            PARSE UPPER VAR eadata 1 . 5 seeding_ea
        IF torrents_dir == config.!torrentdir THEN DO
            IF seeding_ea == '1' THEN DO
                /* File is in downloading directory but marked as seeding.  Move
                 * it to the seeding directory.
                 */
                IF VerifyDirectory( config.!seeddir ) == 1 THEN DO
                    CALL VRCopyFile torfiles.i, config.!seeddir'\' || FILESPEC('NAME', torfiles.i )
                    CALL VRDeleteFile torfiles.i
                    IF VRFileExists( torfiles.i || '.bf') == 1 THEN
                        CALL VRDeleteFile torfiles.i || '.bf'
                    ITERATE
                END
            END
        END
        ELSE IF torrents_dir == config.!seeddir THEN DO
            IF seeding_ea \= '1' THEN DO
                /* File is in seeding directory but is not marked as seeding.
                 * This is a risky situation because we MUST NOT start seeding
                 * a file which isn't really complete.  So we need to ask the
                 * user what to do with it.
                 */
                IF config.!confirmseed == 0 THEN
                    choice = 1
                ELSE DO
                    message.1 = 'Torrent file "' FILESPEC('NAME', torfiles.i )'" is in the ' ||,
                                'seeding directory, but has not been marked as complete.  '  ||,
                                '(This may occur if you are importing an independently-'     ||,
                                'downloaded torrent into FrontenACT for the first time.)'
                    message.2 = ''
                    message.3 = 'You must ONLY allow this torrent to be seeded if you are ' ||,
                                '100% certain that the download is complete!'
                    message.4 = ''
                    message.5 = 'Allow this torrent to be seeded?'
                    message.6 = ''
                    message.7 = '(If you select "No", FrontenACT will automatically move ' ||,
                                'the file into the incomplete torrents directory.)'
                    message.0 = 7
                    buttons.1 = 'Yes'
                    buttons.2 = 'No'
                    buttons.3 = 'Skip'
                    buttons.0 = 3
                    choice = VRMessageStem( VRWindow(), 'message.', 'Warning', 'W', 'buttons.', 2, 3 )
                END
                SELECT
                    WHEN choice == 1 THEN DO
                        /* Set the seeding EA.
                         */
                        ok = SysPutEA( torfiles.i, 'PMFACT.Seeding', X2C('FDFF010031'))
                        statustext = 'Complete'
                    END
                    WHEN choice == 2 THEN DO
                        /* 'No': Move it to the downloading directory.
                         */
                        IF VerifyDirectory( config.!torrentdir ) == 1 THEN DO
                            CALL VRCopyFile torfiles.i, config.!torrentdir'\' || FILESPEC('NAME', torfiles.i )
                            CALL VRDeleteFile torfiles.i
                            IF VRFileExists( torfiles.i || '.bf') == 1 THEN
                                CALL VRDeleteFile torfiles.i || '.bf'
                            IF global.!debug == 1 THEN SAY 'Moved' torfiles.i 'into' config.!torrentdir'.'
                            torfiles.i = config.!torrentdir'\' || FILESPEC('NAME', torfiles.i )
                        END
                        statustext = ''
                    END
                    OTHERWISE ITERATE
                END
            END
            ELSE
                statustext = 'Complete'
        END

        /* Create a new container record for this client.
         */
        c_record = VRMethod('CN_TORRENTS', 'AddRecord',,, torfiles.i, '$4')
        u_record = VRMethod("CN_UPDATE",   "AddRecord",,, torfiles.i, '$4')
        CALL VRMethod 'CN_TORRENTS', 'SetRecordAttr', c_record, 'UserData', u_record
        CALL VRMethod 'CN_UPDATE',   'SetRecordAttr', u_record, 'UserData', c_record
        IF global.!debug == 1 THEN
            SAY 'Created record' c_record '('u_record') for existing file' torfiles.i

        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', c_record,,
                      global.!fields.!name,     FILESPEC('NAME', torfiles.i ),,
                      global.!fields.!icon,     '$4',,
                      global.!fields.!size,     '',,
                      global.!fields.!ipaddr,   '',,
                      global.!fields.!x_socket, 0
        CALL VRMethod 'CN_UPDATE', 'SetFieldData', u_record,,
                      global.!ufields.!name,     torfiles.i,,
                      global.!ufields.!icon,     '$4',,
                      global.!ufields.!size,     '',,
                      global.!ufields.!ipaddr,   'localhost',,
                      global.!ufields.!x_socket, 0

        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', c_record, global.!fields.!status,  statustext
        CALL VRMethod 'CN_UPDATE',   'SetFieldData', u_record, global.!ufields.!status, statustext

    END
    IF torfiles.0 > 0 THEN CALL VRMethod 'CN_TORRENTS', 'SortRecords'

RETURN

/*:VRX         ApplyStartOptions
*/
ApplyStartOptions: PROCEDURE EXPOSE global. config. filefields. dl_dir run_command torrent

    /* Get the startup parameters.
     */
    run_command = VRGet('EF_STCOMMAND', 'Value')
    IF POS( config.!ctorrent, run_command ) == 0 THEN DO
        CALL VRMessage VRWindow(), 'CTorrent command line appears to be invalid.', 'Error', 'E'
        RETURN 1
    END

    torrent = STRIP( VRGet('EF_STTORRENT', 'UserData'))
    IF torrent == '' THEN DO
        CALL VRMessage VRWindow(), 'Invalid torrent string - program error?', 'Error', 'E'
        RETURN 2
    END

    dl_dir = VRExpandFileName( STRIP( VRGet('EF_STSAVEDIR', 'Value')))
    IF dl_dir == '' THEN dl_dir = config.!downloaddir

    /* Save the command-line to the EAs.
     */
    lenbytes = X2C( D2X( LENGTH( run_command ), 4 ))
    eabytes  = X2C('FDFF') || REVERSE( lenbytes ) || run_command
    ok = SysPutEA( torrent, 'PMFACT.Command', eabytes )
    IF ok \= 0 THEN DO
        CALL VRMessage VRWindow(), 'Failed to save torrent file attributes.  SysPutEA returned' ok'.', 'Error', 'E'
        RETURN 1
    END

    /* Save the download directory to the EAs.
     */
    lenbytes = X2C( D2X( LENGTH( dl_dir ), 4 ))
    eabytes  = X2C('FDFF') || REVERSE( lenbytes ) || dl_dir
    ok = SysPutEA( torrent, 'PMFACT.SavePath', eabytes )
    IF ok \= 0 THEN DO
        CALL VRMessage VRWindow(), 'Failed to set torrent file attributes.  SysPutEA returned' ok'.', 'Error', 'E'
        RETURN 1
    END

RETURN 0

/*:VRX         BuildTorrentCmd
*/
BuildTorrentCmd: PROCEDURE EXPOSE global. config. filefields.

    ct_name = TRANSLATE( VRParseFilePath( config.!ctorrent, 'N'))

    /* Basic parameters.
     */
    ctparms = '-d -S localhost:'config.!ctcsport

    /* Filename encoding parameters.
     */
    IF ( ct_name == 'ACT') THEN DO
        _convert  = VRGet('CHK_STCONVERT', 'Set')
        IF _convert \= 1 THEN ctparms = ctparms '-utf'
        ctparms = ctparms '-fenc 1208'
    END

    /* Cache parameter.
     */
    IF global.!defaults.!cachesize <> '' THEN
        ctparms = ctparms '-C' global.!defaults.!cachesize

    /* Tracker selection parameters.
     */
    _tracker = VRGet('CMB_STTRACKER', 'Selected')
    _trackno = VRMethod('CMB_STTRACKER', 'GetItemData', _tracker )
    IF _trackno > 0 & ( ct_name \= 'CTORRENT9') THEN
        ctparms = ctparms '-u' _trackno

    /* File selection parameters.
     */
    CALL VRMethod 'CN_STFILES', 'GetRecordList', 'All', 'allfiles.'
    CALL VRMethod 'CN_STFILES', 'GetRecordList', 'Selected', 'selfiles.'
    IF ( selfiles.0 > 0 ) & ( selfiles.0 < allfiles.0 ) & ( selfiles.0 < 100 ) THEN DO
        getfiles.0 = selfiles.0
        filelist = ''
        DO i = 1 TO selfiles.0
            _fileno = VRMethod('CN_STFILES', 'GetFieldData', selfiles.i, filefields.!number )
            filelist = filelist || _fileno','
        END
        filelist = STRIP( filelist, 'T', ',')
        IF TRANSLATE( VRParseFilePath( config.!ctorrent, 'N')) == 'ACT' THEN
            ctparms = ctparms '-file' filelist
        ELSE
            ctparms = ctparms '-n' filelist
    END

RETURN config.!ctorrent ctparms

/*:VRX         CHK_CTCACHE_Click
*/
CHK_CTCACHE_Click:
    CALL VRSet 'SPIN_CTCACHE', 'Enabled', VRGet('CHK_CTCACHE', 'Set')
return

/*:VRX         CHK_STCONVERT_Click
*/
CHK_STCONVERT_Click:
    CALL VRSet 'EF_STCOMMAND', 'Value', BuildTorrentCmd()
return

/*:VRX         CMB_PREFONEXIT_Change
*/
CMB_PREFONEXIT_Change: PROCEDURE
    IF VRGet('CMB_PREFONEXIT', 'Selected') == 1 THEN
        _enable = 0
    ELSE
        _enable = 1
    CALL VRSet 'CHK_PREFCONFIRM', 'Enabled', _enable
RETURN

/*:VRX         CMB_PREFSTART_Change
*/
CMB_PREFSTART_Change: PROCEDURE
    idx = VRGet('CMB_PREFSTART', 'Selected')
    IF idx > 1 THEN
        _enable = 1
    ELSE
        _enable = 0
    CALL VRSet 'CHK_PREFDIALOG', 'Enabled', _enable
RETURN

/*:VRX         CMB_STTRACKER_Change
*/
CMB_STTRACKER_Change:
    CALL VRSet 'EF_STCOMMAND', 'Value', BuildTorrentCmd()
return

/*:VRX         CN_STFILES_Click
*/
CN_STFILES_Click:
    CALL VRSet 'EF_STCOMMAND', 'Value', BuildTorrentCmd()
return

/*:VRX         CN_TORRENTS_Click
*/
CN_TORRENTS_Click:
    CALL UpdateMenuItems
RETURN

/*:VRX         CN_TORRENTS_ContextMenu
*/
CN_TORRENTS_ContextMenu:
    ok = VRMethod('CN_TORRENTS', 'GetRecordList', 'Selected', 'records.')
    IF ( ok == 0 ) | ( records.0 < 1 ) THEN RETURN 0

    _record = VRInfo('Record')
    IF _record \= '' THEN DO
        CALL VRMethod 'CN_TORRENTS', 'SetRecordAttr', _record, 'Selected', 1
    END

    CALL VRMethod 'MN_SELECTED', 'Popup'
RETURN

/*:VRX         CN_TORRENTS_DragDrop
*/
CN_TORRENTS_DragDrop: PROCEDURE EXPOSE global. config.
    source = VRInfo('SourceFile')
    index  = VRInfo('DragIndex')
    total  = VRInfo('DragTotal')

RETURN

/*:VRX         ConfirmStop
*/
ConfirmStop: PROCEDURE EXPOSE global. config.
    IF ( config.!onexit < 2 ) | ( config.!confirmexit == 0 ) THEN RETURN 1

    /* Get the list of torrent IDs to be stopped.
     */
    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'All', 'torrents.'
    stop_count = 0
    DO i = 1 TO torrents.0
        _type = VRMethod('CN_TORRENTS', 'GetFieldData', torrents.i, global.!fields.!icon )
        IF config.!onexit == 3 | _type == '$3' THEN
            stop_count = stop_count + 1
    END

    /* Ask for confirmation (if requested).
     */
    IF stop_count > 0 THEN DO
        SELECT
            WHEN config.!onexit == 2 THEN msgtext = 'Stop' stop_count 'locally-running torrents before exiting?'
            WHEN config.!onexit == 3 THEN msgtext = 'Stop all torrents before exiting?'
            OTHERWISE msgtext = ''
        END
        buttons.1 = 'Yes'
        buttons.2 = 'No'
        buttons.3 = 'Cancel'
        buttons.0 = 3
        ok = VRMessage( VRWindow(), msgtext, 'Confirm Exit', 'Q', 'buttons.', 1, 3 )
        RETURN ok
    END

RETURN 1

/*:VRX         CreateClientRecord
*/
/* Create a new record representing an actively-running torrent, as reported
 * via a CTCS client connection.
 */
CreateClientRecord: PROCEDURE EXPOSE global. config.
    PARSE ARG c_sock, c_torrentfile

    _filename = FILESPEC('NAME', c_torrentfile )

    /* Find out the IP address of the connection.
     */
    rc = SockGetPeerName( c_sock, 'address.!')
    IF rc == 0 THEN
        c_ipaddr = address.!addr
    ELSE
        c_ipaddr = 'Unknown host'

    IF c_ipaddr == '127.0.0.1' THEN DO
        c_ipaddr = 'localhost'
        _icon    = '$3'
    END
    ELSE
        _icon = '$5'

    /* Search inactive records for this filename and use/replace if found
     */
    c_record = FindTorrentRecord( c_torrentfile )
    u_record = ''

    /* Otherwise, add a new record to the container.
     */
    IF c_record == '' THEN DO
        c_record = VRMethod("CN_TORRENTS", "AddRecord",,, c_torrentfile, _icon )
        u_record = VRMethod("CN_UPDATE",   "AddRecord",,, c_torrentfile, _icon )
        CALL VRMethod 'CN_TORRENTS', 'SetRecordAttr', c_record, 'UserData', u_record
        CALL VRMethod 'CN_UPDATE',   'SetRecordAttr', u_record, 'UserData', c_record
        IF global.!debug == 1 THEN
            SAY 'Created record' c_record '('u_record') for torrent' _filename 'on socket' c_sock
    END
    ELSE DO
        u_record = VRMethod('CN_TORRENTS', 'GetRecordAttr', c_record, 'UserData')
        IF global.!debug == 1 THEN
            SAY 'Replacing record' c_record '('u_record') for torrent' _filename 'on socket' c_sock
    END

    IF c_record == '' | u_record == '' THEN RETURN 1
    global.!records.c_sock = c_record
    global.!updrecs.c_sock = u_record

    CALL VRMethod 'CN_TORRENTS', 'SetFieldData', c_record,,
                  global.!fields.!name,     _filename,,
                  global.!fields.!icon,     _icon,,
                  global.!fields.!size,     '...',,
                  global.!fields.!x_socket, c_sock,,
                  global.!fields.!status,   ''

    CALL VRMethod 'CN_UPDATE', 'SetFieldData', u_record,,
                  global.!ufields.!name,       c_torrentfile,,
                  global.!ufields.!icon,       _icon,,
                  global.!ufields.!size,       '',,
                  global.!ufields.!x_socket,   c_sock,,
                  global.!ufields.!status,     ''

    IF c_ipaddr <> 'localhost' THEN
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', c_record, global.!fields.!ipaddr,  '('c_ipaddr')'
    CALL VRMethod 'CN_UPDATE',   'SetFieldData', u_record, global.!ufields.!ipaddr, c_ipaddr

    CALL VRMethod 'CN_TORRENTS', 'SortRecords'
    CALL VRSet 'TM_REFRESH', 'Enabled', 1

RETURN

/*:VRX         CTCS_Init
*/
CTCS_Init: PROCEDURE EXPOSE config. global.

    socket = SockSocket('AF_INET', 'SOCK_STREAM', 0 )
    IF socket < 0 THEN RETURN SockSock_Errno()

    rc = SockSetSockOpt( socket, 'SOL_SOCKET', 'SO_LINGER', '1 2')
    rc = SockSetSockOpt( socket, 'SOL_SOCKET', 'SO_REUSEADDR', 1 )

    address.!family = 'AF_INET'
    address.!port   = config.!ctcsport
    address.!addr   = 'INADDR_ANY'

    rc = SockBind( socket, 'address.!')
    IF rc < 0 THEN RETURN SockSock_Errno()
    rc = SockListen( socket, 5 )
    IF rc < 0 THEN RETURN SockSock_Errno()

    global.!listen_socket = socket
    global.!listen_thread = VRMethod('Application', 'StartThread', 'Listener', socket )
    IF global.!listen_thread < 0 THEN RETURN -1

    global.!client_thread = VRMethod('Application', 'StartThread', 'ClntMgr', global.!debug )
    IF global.!client_thread < 0 THEN RETURN -1

RETURN 0

/*:VRX         CTCS_SendCommand
*/
CTCS_SendCommand: PROCEDURE EXPOSE global.
    PARSE ARG client, command

    rc = VRMethod('Application', 'PostQueue', global.!client_thread, 0, 'CALL Event_SendCommand' client command )
    IF rc == 0 THEN SAY 'Failed to post event to thread' thread'!'

RETURN rc

/*:VRX         CTCS_Shutdown
*/
CTCS_Shutdown:
    /* Used to shut down the program cleanly by telling the network activity
     * threads to finish up (closing all sockets etc.).
     */
    CALL VRMethod 'Application', 'PostQueue', global.!listen_thread, 0, 'finished = 1'
    rc = VRMethod('Application', 'PostQueue', global.!client_thread, 0, 'finished = 1')

RETURN rc

/*:VRX         EF_CTEXE_KeyPress
*/
EF_CTEXE_KeyPress: PROCEDURE
    kstr = VRGet('EF_CTEXE', 'KeyString')
    IF kstr == '{Enter}' | kstr == '{Newline}' THEN
        CALL PB_CTOK_Click
RETURN

/*:VRX         EF_CTTRACKERS_KeyPress
*/
EF_CTTRACKERS_KeyPress: PROCEDURE
    kstr = VRGet('EF_CTTRACKERS', 'KeyString')
    IF kstr == '{Enter}' | kstr == '{Newline}' THEN
        CALL PB_CTADDTRK_Click
RETURN

/*:VRX         Event_CTDead
*/
Event_CTDead: PROCEDURE EXPOSE config. global.
    PARSE ARG _client

    IF _client == '' THEN RETURN 1
    _record = global.!updrecs._client
    IF _record == '' THEN RETURN 3

    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _record, global.!ufields.!icon,     '$6',,
                                                        global.!ufields.!dlrate,   0,,
                                                        global.!ufields.!ulrate,   0,,
                                                        global.!ufields.!timemark, '0'
    IF global.!debug THEN
        SAY 'Client' _client 'has stopped responding.'

RETURN 0

/*:VRX         Event_CTDetail
*/
Event_CTDetail: PROCEDURE EXPOSE global.
    PARSE ARG _client

    IF _client == '' THEN RETURN 1

    _ctdata = VRInfo('CTData')
    IF _ctdata == '' THEN RETURN 2

    _record = global.!updrecs._client
    IF _record == '' THEN RETURN 3

    /* Update the size field in the main container.
     */
    PARSE VAR _ctdata _size .
    IF Utils('IsNumber', _size ) THEN DO
        ok = VRMethod('CN_UPDATE', 'SetFieldData', _record, global.!ufields.!size, _size )
    END
    ELSE DO
        ok = VRMethod('CN_UPDATE', 'SetFieldData', _record, global.!ufields.!size, '')
    END

    /* TODO pass data along to the details notebook, if open.
     */

RETURN 0

/*:VRX         Event_CTorrent
*/
Event_CTorrent: PROCEDURE EXPOSE config. global.
    PARSE ARG _client

    /* This function handles the first update of a connected torrent client
     * AFTER it is connected.  It is triggered by the connection-management
     * thread on receipt of a CTORRENT message, and is called only once
     * (right after the initial connection is made).
     */

    IF _client == '' THEN RETURN 1

    _file   = VRInfo('CTFileName')
    _peerid = VRInfo('CTPeerID')

    IF _file == '' THEN RETURN 2

    CALL CreateClientRecord _client, _file
    CALL UpdateMenuItems

    /* Getting the torrent size requires a CTDETAILS message, so now we ask the
     * connection-management thread to request one.
     */
    CALL CTCS_SendCommand _client, 'SENDDETAIL'

RETURN 0

/*:VRX         Event_CTUpdateLong
*/
Event_CTUpdateLong: PROCEDURE EXPOSE config. global.
    PARSE ARG _client

    _ctdata = VRInfo('CTData')

    IF _client == '' THEN RETURN 1
    IF _ctdata == '' THEN RETURN 2

    _record = global.!updrecs._client
    IF _record == '' THEN RETURN 3

    PARSE VAR _ctdata seeders tseeders leechers tleechers cnct have total avail dlrate ulrate dltotal ultotal

    _tmarks = VRMethod('CN_UPDATE', 'GetFieldData', _record, global.!ufields.!timemark )
    _cmarks = WORDS( _tmarks )
    IF _cmarks < 1 THEN
        _tmarks = dlrate
    ELSE IF _cmarks < 10 THEN
        _tmarks = _tmarks dlrate
    ELSE
        _tmarks = SUBWORD( _tmarks, 2, 9 ) dlrate

    PARSE VALUE VRMethod('CN_UPDATE', 'GetFieldData', _record, global.!ufields.!pieces ) WITH old_have '/' .

    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _record, global.!ufields.!pieces,   have'/'avail'/'total,,
                                                        global.!ufields.!seeders,  seeders '('tseeders')',,
                                                        global.!ufields.!leechers, leechers '('tleechers')',,
                                                        global.!ufields.!timemark, _tmarks
    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _record, global.!ufields.!dlrate,  dlrate,,
                                                        global.!ufields.!ulrate,  ulrate,,
                                                        global.!ufields.!dloaded, dltotal,,
                                                        global.!ufields.!uloaded, ultotal

    _address = VRMethod('CN_UPDATE', 'GetFieldData', _record, global.!ufields.!ipaddr )
    IF _address == 0 | address == '' THEN RETURN 0

    /* Mark torrent file as complete (seeding) if we have all the pieces.
     */
    IF ( have == total & have \= old_have ) THEN DO
        _filename = VRMethod('CN_UPDATE', 'GetFieldData', _record, global.!ufields.!name )
        IF VRFileExists( _filename ) THEN DO
            ok = SysPutEA( _filename, 'PMFACT.Seeding', X2C('FDFF010031'))
        END
        CALL VRMethod 'CN_UPDATE', 'SetFieldData', _record, global.!ufields.!status, 'Complete'
    END

RETURN 0

/*:VRX         Event_CTUpdateShort
*/
Event_CTUpdateShort: PROCEDURE EXPOSE config. global.
    PARSE ARG _client

    _ctdata = VRInfo('CTData')

    IF _client == '' THEN RETURN 1
    IF _ctdata == '' THEN RETURN 2

    _record = global.!updrecs._client
    IF _record == '' THEN RETURN 3

    PARSE VAR _ctdata dlrate ulrate

    _tmarks = VRMethod('CN_UPDATE', 'GetFieldData', _record, global.!ufields.!timemark )
    _cmarks = WORDS( _tmarks )
    IF _cmarks < 1 THEN
        _tmarks = dlrate
    ELSE IF _cmarks < 10 THEN
        _tmarks = _tmarks dlrate
    ELSE
        _tmarks = SUBWORD( _tmarks, 2, 9 ) dlrate

    ok = VRMethod('CN_UPDATE', 'SetFieldData', _record, global.!ufields.!dlrate, dlrate,,
                                                        global.!ufields.!ulrate, ulrate,,
                                                        global.!ufields.!timemark, _tmarks )

RETURN

/*:VRX         Event_Disconnect
*/
Event_Disconnect: PROCEDURE EXPOSE config. global.
    /* Called when a CTCS client disconnects.  This may be because the user
     * stopped it, because a fully-downloaded torrent has reached its seed
     * target and ended automatically, or because the CTorrent process
     * terminated for some other reason.  (There is no way to distinguish
     * between these types of termination.)
     */

    PARSE ARG _client
    IF _client == '' THEN RETURN 1

    /* Get the container record of the client which has stopped.
     */
    IF SYMBOL('global.!records._client') == 'LIT' THEN RETURN 2
    IF SYMBOL('global.!updrecs._client') == 'LIT' THEN RETURN 2
    _vrecord = global.!records._client
    _urecord = global.!updrecs._client

    IF _vrecord == '' THEN RETURN 3
    IF _urecord == '' THEN RETURN 3

    /* Get the torrent filepsec and see if it's a locally-managed file.
     */
    torrent_file = VRMethod('CN_UPDATE', 'GetFieldData', _urecord, global.!ufields.!name )
    torrent_host = VRMethod('CN_UPDATE', 'GetFieldData', _urecord, global.!ufields.!ipaddr )
    PARSE UPPER VALUE VRParseFilePath( torrent_file, 'DP') WITH _filepath

    /* Just remove the record if it's a remote torrent.
     */
    IF torrent_host <> 'localhost' THEN DO
        CALL VRMethod 'CN_UPDATE',   'RemoveRecord', _urecord
        CALL VRMethod 'CN_TORRENTS', 'RemoveRecord', _vrecord
        IF config.!debug == 1 THEN
            SAY 'Remote torrent' FILESPEC('NAME', torrent_file ) 'has stopped.'
        RETURN 0
    END

    /* Locally-mananged torrent: set the state to inactive and update the record.
     */
    ELSE IF _filepath == TRANSLATE( config.!seeddir ) THEN DO
        _status = 'Complete'
    END
    ELSE IF _filepath == TRANSLATE( config.!torrentdir ) THEN DO
        _status  = ''
        _seed_ea = 0
        IF SysGetEA( torrent_file, 'PMFACT.Seeding', 'eadata') == 0 THEN
            PARSE UPPER VAR eadata 1 . 5 _seed_ea
        IF _seed_ea == 1 THEN
            _status = 'Complete'
    END
    ELSE DO
        IF global.!debug == 1 THEN
            SAY 'Cannot match path ('_filepath') of stopped torrent' torrent_file
        _status = ''
    END

    IF global.!debug == 1 THEN
        SAY 'Torrent' torrent_file 'has stopped. Updating status.'

    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _urecord, global.!ufields.!icon,     '$4',,
                                                         global.!ufields.!size,     '',,
                                                         global.!ufields.!pieces,   '',,
                                                         global.!ufields.!timemark, ''
    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _urecord, global.!ufields.!dlrate,   '',,
                                                         global.!ufields.!ulrate,   '',,
                                                         global.!ufields.!dloaded,  '',,
                                                         global.!ufields.!uloaded,  ''
    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _urecord, global.!ufields.!seeders,  '',,
                                                         global.!ufields.!leechers, '',,
                                                         global.!ufields.!status,   _status
    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _urecord, global.!ufields.!x_socket, 0,,
                                                         global.!ufields.!ipaddr,   0,,
                                                         global.!ufields.!x_dtid,   0

    DROP global.!records._client
    DROP global.!updrecs._client

    CALL UpdateMenuItems
RETURN 0

/*:VRX         Event_Incoming
*/
Event_Incoming: PROCEDURE EXPOSE config. global.

    /* This function processes a new incoming client connection.
     */

    c_sock = VRInfo('ClientSocket')
    IF c_sock == '' | c_sock < 0 THEN RETURN -1

    global.!records.c_sock = ''
    global.!updrecs.c_sock = ''

    rc = SockSetSockOpt( c_sock, 'SOL_SOCKET', 'SO_RCVTIMEO', '3 0')
    rc = SockSetSockOpt( c_sock, 'SOL_SOCKET', 'SO_LINGER',   '0 1')
    rc = SockSetSockOpt( c_sock, 'SOL_SOCKET', 'SO_REUSEADDR',  '1')

    IF global.!debug == 1 THEN
        SAY 'Adding new connection on socket' c_sock'...'

    /* Pass the new socket to the client-connection management thread.
     */
    rc = VRMethod('Application', 'PostQueue', global.!client_thread, 0, 'CALL Event_New' c_sock )

RETURN 0

/*:VRX         Event_Status
*/
Event_Status:
    PARSE ARG _client

    IF _client == '' THEN RETURN 1

    _ctdata = VRInfo('CTData')
    IF _ctdata == '' THEN RETURN 2

    _record = global.!updrecs._client
    IF _record == '' THEN RETURN 3

    CALL VRMethod 'CN_UPDATE', 'SetFieldData', _record,,
                               global.!ufields.!status, _ctdata

RETURN

/*:VRX         FindTorrentRecord
*/
FindTorrentRecord: PROCEDURE EXPOSE global. config.
    /* See if a specified torrent file has an existing record in 'inactive'
     * state.  Called when a new CTCS connection is received, so that we can
     * associate the reported torrent with its existing record (if one exists).
     */
    PARSE UPPER ARG find_torrent

    find_torrent = STRIP( find_torrent )
    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'All', 'records.'
    IF records.0 < 1 THEN RETURN ''

    DO i = 1 TO records.0
        /* Only check inactive records (which have a non-zero socket value).
         */
        _type = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!x_socket )
        IF _type \= 0 THEN ITERATE
        PARSE UPPER VALUE VRMethod('CN_TORRENTS', 'GetRecordAttr', records.i, 'Caption') WITH _torrent
        /* Check both the active and seeding directories in case the file was
         * moved since the client process began.
         */
        torrent_file = VRParseFilePath( _torrent, 'NE')
        torrent_down = TRANSLATE( config.!torrentdir'\'torrent_file )
        torrent_seed = TRANSLATE( config.!seeddir'\'torrent_file )
        IF ( _torrent == find_torrent | torrent_down == find_torrent | torrent_seed == find_torrent ) THEN DO
            IF global.!debug == 1 THEN
                SAY 'Found record' records.i 'for torrent' find_torrent
            RETURN records.i
        END
    END

RETURN ''

/*:VRX         Fini
*/
Fini:
    window = VRWindow()
    call VRSet window, "Visible", 0
    drop window
return 0

/*:VRX         GetTorrentContents
*/
GetTorrentContents: PROCEDURE EXPOSE global. config. trackers. tracknos. files. filenos. deftracker totalsize directory
    PARSE ARG torfile

    /* Run CTorrent with '-x' to get information about the torrent contents.
     */
    ctparms = '-x -S localhost:'config.!ctcsport
    IF ( TRANSLATE( VRParseFilePath( config.!ctorrent, 'N')) == 'ACT') & ( global.!defaults.!convertcp == 0 ) THEN
        ctparms = ctparms '-utf -fenc 1208'

    act_q = RXQUEUE('CREATE')
    std_q = RXQUEUE('SET', act_q )
    ADDRESS CMD config.!ctorrent ctparms '"'torfile'" |RXQUEUE' act_q
    i = 0
    output.0 = 0
    DO QUEUED()
        PARSE PULL _line
        i = i + 1
        output.i = _line
    END
    output.0 = i
    CALL RXQUEUE 'SET',    std_q
    CALL RXQUEUE 'DELETE', act_q

    deftracker = 'No Tracker'
    trackers.0 = 0
    tracknos.0 = 0
    directory  = ''
    files.0    = 0
    filenos.0  = 0
    totalsize  = ''

    /* Now parse the information.
     */
    _section = ''
    t_cnt    = 0
    f_cnt    = 0
    DO i = 1 TO output.0
        IF output.i == 'META INFO' THEN       _section = 'META'
        ELSE IF output.i == 'FILES INFO' THEN _section = 'FILES'
        ELSE IF ( output.i == 'Alternates:' & _section == 'META') THEN _section = 'TLIST'
        ELSE DO
            IF _section == 'META' THEN DO
                IF WORD( output.i, 1 ) == 'Announce:' THEN DO
                    PARSE VAR output.i ':' _tracker
                    deftracker = STRIP( _tracker )
                END
            END
            ELSE IF _section == 'TLIST' THEN DO
                PARSE VAR output.i _no '.' _tracker
                _no = STRIP( _no )
                _tracker = STRIP( _tracker )
                IF Utils('IsNumber', _no ) THEN DO
                    t_cnt = t_cnt + 1
                    trackers.t_cnt = _tracker
                    tracknos.t_cnt = _no
                END
                ELSE _section = 'META'
            END
            ELSE IF _section = 'FILES' THEN DO
                IF WORD( output.i, 1 ) == 'Directory:' THEN DO
                    PARSE VAR output.i ':' _directory
                    directory = STRIP( _directory )
                END
                ELSE IF WORD( output.i, 1 ) == 'Total:' THEN DO
                    PARSE VAR output.i ':' _totsize
                    totalsize = STRIP( _totsize )
                END
                ELSE DO
                    PARSE VAR output.i '<'_no'>' _file
                    _no = STRIP( _no )
                    _file = STRIP( _file )
                    IF Utils('IsNumber', _no ) THEN DO
                        f_cnt = f_cnt + 1
                        files.f_cnt   = _file
                        filenos.f_cnt = _no
                    END
                END
            END
        END
    END
    trackers.0 = t_cnt
    tracknos.0 = t_cnt
    files.0    = f_cnt
    filenos.0  = f_cnt

RETURN

/*:VRX         Halt
*/
Halt:
    signal _VREHalt
return

/*:VRX         Init
*/
Init:
    NUMERIC DIGITS 11
    SIGNAL ON NOVALUE NAME _NoValue

    CALL RxFuncAdd 'SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs'
    CALL SysLoadFuncs
    CALL RxFuncAdd 'SockLoadFuncs', 'RXSOCK', 'SockLoadFuncs'
    CALL SockLoadFuncs

    global.!debug = 0

    DO i = 1 TO InitArgs.0
        _arg = TRANSLATE( LEFT( InitArgs.i, 2 ))
        IF ( _arg == '-D') | ( _arg == '/D') THEN global.!debug = 1
    END
    IF global.!debug == 0 THEN DO
        CALL VRSet 'Console', 'WindowListTitle', ''
    /*  CALL VRRedirectStdIO('Off') */
    END

    IF global.!debug == 1 THEN DO 
        SAY 'Libraries loaded:' 
        SAY ' - REXXUTIL:' SysUtilVersion()
        SAY ' - RXSOCK:  ' SockVersion()
    END

    s_rc = SockInit()
    IF s_rc \= 0 THEN DO
        CALL VRMessage 'WN_MAIN', 'TCP/IP is not available.', 'Error', 'E'
        CALL HALT
    END

    CALL SetupDefaults
    CALL SetupLocale
    CALL SetupContainer
    CALL ProfileLoad

    /* Add our own directory to the PATH for this session (allows CTorrent to
     * be kept in the same directory without needing to specify the FQN).
     */
    exepath = TRANSLATE( VALUE('PATH',,'OS2ENVIRONMENT'))
    IF POS( TRANSLATE(config.!mydir), exepath) == 0 THEN DO
        exepath = STRIP( exepath, 'T', ';') || ';'config.!mydir';'
        CALL VALUE 'PATH', exepath, 'OS2ENVIRONMENT'
    END

    window = VRWindow()
    call VRSet window, "Visible", 1
    call VRMethod window, "Activate"
    drop window

    CALL AddExistingTorrents config.!torrentdir
    CALL AddExistingTorrents config.!seeddir

    CALL SetContainerSort

    /* Start the daemon (connection listener) thread
     */
    global.!listen_thread = -1
    global.!listen_socket = 0
    init_rc = CTCS_Init()
    SELECT
        WHEN init_rc < 0 THEN DO
            CALL VRMessage 'WN_MAIN', 'Failed to start daemon thread.', 'Error', 'E'
            CALL Quit
        END
        WHEN init_rc > 0 THEN DO
            CALL VRMessage 'WN_MAIN', 'Failed to initialize daemon socket: TCP/IP error' init_rc'.', 'Error', 'E'
            CALL Quit
        END
        OTHERWISE NOP
    END

RETURN

/*:VRX         IsTorrent
*/
IsTorrent: PROCEDURE
    PARSE ARG checked_file

    CALL LINEIN checked_file, 1, 0
    head = CHARIN( checked_file,, 11 )
    CALL STREAM checked_file, 'C', 'CLOSE'

    IF head == 'd8:announce' THEN RETURN 1

    IF global.!debug == 1 THEN
        SAY 'File "'checked_file'" is not a torrent file (will skip).'

RETURN 0

/*:VRX         LB_CTTRACKERS_Click
*/
LB_CTTRACKERS_Click: PROCEDURE
    address = VRGet('LB_CTTRACKERS', 'SelectedString')
    IF address == '' THEN RETURN
    CALL VRSet 'EF_CTTRACKERS', 'Value', address
RETURN

/*:VRX         MI_ABOUT_Click
*/
MI_ABOUT_Click:
    CALL VRLoadSecondary 'SW_ABOUT', 'W'
RETURN

/*:VRX         MI_CTORRENT_Click
*/
MI_CTORRENT_Click: PROCEDURE EXPOSE global. config.
    CALL VRLoadSecondary 'SW_CTORRENT', 'W'
RETURN

/*:VRX         MI_DELETE_Click
*/
MI_DELETE_Click:

    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'Selected', 'records.'
    IF records.0 < 1 THEN RETURN 0

    DO i = 1 TO records.0
        _client = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!x_socket )
        _icon   = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!icon     )
        IF _client <> 0 THEN DO
            _torrent = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!name )
            CALL VRMessage VRWindow(), 'Torrent' _torrent 'cannot be removed as it is currently active.',,
                           'Cannot Remove Torrent', 'W'
            ITERATE
        END
        ELSE IF _icon <> '$4' THEN DO
            _torrent = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!name )
            CALL VRMessage VRWindow(), 'Torrent' _torrent 'cannot be removed as a start or stop operation is still in progress.',,
                           'Cannot Remove Torrent', 'W'
            ITERATE
        END

        c_record = records.i
        u_record = VRMethod('CN_TORRENTS', 'GetRecordAttr', c_record, 'UserData')
        IF u_record <> '' THEN DO
            torrent_file = VRMethod('CN_UPDATE', 'GetFieldData', u_record, global.!ufields.!name )
            CALL VRMethod 'CN_UPDATE', 'RemoveRecord', u_record
        END
        ELSE
            torrent_file = VRMethod('CN_TORRENTS', 'GetRecordAttr', c_record, 'Caption')

        c_sock = VRMethod('CN_TORRENTS', 'GetFieldData', c_record, global.!fields.!x_socket )
        IF c_sock > 0 THEN DO
            DROP global.!records.c_sock
            DROP global.!updrecs.c_sock
        END

        IF global.!debug == 1 THEN SAY 'Removing record' c_record '('u_record') for torrent' torrent_file
        CALL VRMethod 'CN_TORRENTS', 'RemoveRecord', c_record

        IF VerifyDirectory( config.!deldir ) == 1 THEN
            CALL VRCopyFile torrent_file, config.!deldir'\' || FILESPEC('NAME', torrent_file )
        ok = VRDeleteFile( torrent_file )
        IF VRFileExists( torrent_file'.bf') == 1 THEN
            CALL VRDeleteFile torrent_file'.bf'

        IF ok == 0 THEN DO
            _error = VRError()
            CALL VRMessage VRWindow(), 'Failed to delete torrent file:' _error, 'Error Deleting File', 'E'
            IF global.!debug == 1 THEN SAY 'VRDeleteFile() failed:' _error
        END
    END
    CALL UpdateMenuItems

RETURN

/*:VRX         MI_DIRS_Click
*/
MI_DIRS_Click: PROCEDURE EXPOSE global. config.
    dirs_changed = 0
    CALL VRLoadSecondary 'SW_DIRS', 'W'
    IF dirs_changed == 1 THEN DO
        config.!torrentdir  = new_downloaddir
        config.!seeddir     = new_seeddir
        config.!deldir      = new_deldir
        config.!downloaddir = new_savedir
    END
RETURN

/*:VRX         MI_EXIT_Click
*/
MI_EXIT_Click:
    CALL QuitWait
RETURN

/*:VRX         MI_OPEN_Click
*/
MI_OPEN_Click:

    torrent_file = VRFileDialog('WN_MAIN', 'Open Torrent', 'O', config.!opendir || '\*')
    IF torrent_file == '' THEN RETURN 0

    config.!opendir = VRParseFilePath( torrent_file, 'DP')
    _record = OpenFile( torrent_file )
    IF _record == '' THEN RETURN 1

    IF config.!autostart < 2 THEN RETURN 0

    ok = StartTorrent( _record )
    IF ok <> 0 THEN DO
        CALL SysFileDelete config.!torrentdir'\' || FILESPEC('NAME', torrent_file )
        CALL VRMessage VRWindow(), 'Failed to start torrent (error code' ok')', 'Error', 'E'
        RETURN 1
    END

RETURN 0

/*:VRX         MI_OPENM_Click
*/
MI_OPENM_Click:

    CALL VRFileDialog 'WN_MAIN', 'Open Torrents', 'O', config.!opendir || '\*',,,,'files.'
    IF files.0 == 0 THEN RETURN 0

    config.!opendir = VRParseFilePath( torrent_file, 'DP')

    IF config.!autostart == 2 & files.0 > 1 THEN do_start = 1
    ELSE do_start = config.!autostart

    CALL VRSet 'CN_TORRENTS', 'Painting', 0
    DO i = 1 TO files.0
        _record = OpenFile( files.i )
        IF _record == '' THEN ITERATE
        IF do_start < 2 THEN ITERATE

        ok = StartTorrent( _record )
        IF ok <> 0 THEN DO
            buttons.1 = 'OK'
            buttons.2 = 'Abort'
            buttons.0 = 2
            CALL SysFileDelete config.!torrentdir'\' || FILESPEC('NAME', torrent_file )
            act = VRMessage( VRWindow(), 'Failed to start torrent (error code' ok')', 'Error', 'E', 'buttons.', 1, 2 )
            IF act == 2 THEN LEAVE
        END
    END
    CALL VRSet 'CN_TORRENTS', 'Painting', 1

RETURN 0

/*:VRX         MI_PREFS_Click
*/
MI_PREFS_Click: PROCEDURE EXPOSE global. config.
    prefs_changed = 0
    CALL VRLoadSecondary 'SW_PREFS', 'W'
    IF prefs_changed == 1 THEN DO
        IF ( config.!sortcolumn \= sortcol ) | ( config.!sorttype \= sortdir ) THEN DO
            config.!sortcolumn = sortcol
            config.!sorttype   = sortdir
            CALL SetContainerSort
        END
        config.!autostart   = autostart
        config.!autodialog  = autodialog
        config.!autoresume  = autoresume
        config.!onexit      = onexit
        config.!confirmexit = confirmquit
        config.!confirmseed = confirmseed
        config.!deleteorg   = deleteorg
        IF ( refresh \= config.!interval ) THEN DO
            config.!interval = refresh
            CALL VRSet 'TM_REFRESH', 'Delay', config.!interval
        END
    END

RETURN

/*:VRX         MI_REFRESH_Click
*/
MI_REFRESH_Click: PROCEDURE EXPOSE global. options.

    /* CALL RefreshFiles */
    /* CALL RefreshDisplay */

RETURN

/*:VRX         MI_RESUME_Click
*/
MI_RESUME_Click:

    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'Selected', 'records.'
    IF records.0 < 1 THEN RETURN 0

    DO i = 1 TO records.0
        _client = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!x_socket )
        IF global.!debug == 1 THEN SAY 'Starting torrent for record' records.i '('_client') ...'
        IF _client <> 0 THEN ITERATE

        _urecord = VRMethod('CN_TORRENTS', 'GetRecordAttr', records.i, 'UserData')
        If _urecord == '' THEN ITERATE

        ok = StartTorrent( _urecord )
        IF ok <> 0 THEN DO
            CALL VRMessage VRWindow(), 'Failed to start torrent (error code' ok')', 'Error', 'E'
            RETURN 1
        END
        IF started == 1 THEN DO
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', records.i,,
                          global.!fields.!icon,   '$2',,
                          global.!fields.!status, 'Starting...'
            CALL VRMethod 'CN_UPDATE', 'SetFieldData', _urecord,,
                          global.!ufields.!icon,   '$2',,
                          global.!ufields.!status, 'Starting...'
        END
    END
    CALL UpdateMenuItems

RETURN

/*:VRX         MI_STARTOPT_Click
*/
MI_STARTOPT_Click:

    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'Selected', 'records.'
    IF records.0 < 1 THEN RETURN 0

    DO i = 1 TO records.0
        _urecord = VRMethod('CN_TORRENTS', 'GetRecordAttr', records.i, 'UserData')
        If _urecord == '' THEN ITERATE

        torrent = VRMethod('CN_UPDATE', 'GetFieldData', _urecord, global.!ufields.!name )
        IF torrent == '' THEN ITERATE

        /* Get the previous options for this torrent so we can pre-populate
         * the dialog controls.
         */
        old_cmdline = ''
        old_savedir = ''
        IF SysGetEA( torrent, 'PMFACT.Command', 'eadata') == 0 THEN DO
            PARSE VAR eadata 1 _type 3 . 5 _value
            IF C2X( _type ) == 'FDFF' THEN old_cmdline = _value
            DROP _type
            DROP _value
        END
        IF SysGetEA( torrent, 'PMFACT.SavePath', 'eadata') == 0 THEN DO
            PARSE VAR eadata 1 _type 3 . 5 _value
            IF C2X( _type ) == 'FDFF' THEN old_savedir = _value
            DROP _type
            DROP _value
        END

        CALL VRLoadSecondary 'SW_START', 'W'
    END
    CALL UpdateMenuItems

    DROP old_cmdline
    DROP old_savedir

RETURN 0

/*:VRX         MI_STOP_Click
*/
MI_STOP_Click:

    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'Selected', 'records.'
    IF records.0 < 1 THEN RETURN 0

    DO i = 1 TO records.0
        _client = VRMethod('CN_TORRENTS', 'GetFieldData', records.i, global.!fields.!x_socket )
        IF _client < 1 THEN ITERATE
        CALL CTCS_SendCommand _client, 'CTQUIT'
        CALL VRMethod 'CN_UPDATE', 'SetFieldData', global.!updrecs._client,,
                                   global.!ufields.!icon,   '$2',,
                                   global.!ufields.!status, 'Stopping...'
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', global.!records._client,,
                                   global.!fields.!icon,     '$2',,
                                     global.!fields.!status, 'Stopping...'
        IF global.!debug == 1 THEN SAY 'Stopping torrent record' global.!records._client '...'
    END
    CALL UpdateMenuItems

RETURN

/*:VRX         OpenFile
*/
/* Open a local torrent file.  Copies the file to the running torrents
 * directory, then creates a record for it.  The torrent status is initially
 * set to inactive (not running); the calling function can then start it (or
 * not) as appropriate according to the current configuration.
 */
OpenFile: PROCEDURE EXPOSE global. config.
    PARSE ARG open_filespec

    IF IsTorrent( open_filespec ) == 0 THEN DO
        CALL VRMessage 'WN_MAIN', open_filespec 'is not a valid bittorrent file.', 'Error', 'E'
        RETURN ''
    END

    /* Check to see if the torrent file is already being managed (locally).
     */
    c_record = ''
    u_record = ''
    new_filespec = config.!torrentdir'\' || FILESPEC('NAME', open_filespec )
    CALL VRMethod 'CN_UPDATE', 'GetRecordList', 'All', 'records.'
    DO i = 1 TO records.0
        type = VRMethod('CN_UPDATE', 'GetFieldData', records.i,,
                         global.!ufields.!ipaddr )
        IF type \= 'localhost' THEN ITERATE
        PARSE UPPER VALUE VRMethod('CN_UPDATE', 'GetFieldData', records.i,,
                                   global.!ufields.!name ) WITH exist_torrent
        IF TRANSLATE( new_filespec ) == exist_torrent THEN DO
            u_record = records.i
            LEAVE
        END
    END
    IF u_record \= '' THEN DO
        IF VRMethod('CN_UPDATE', 'GetFieldData', records.i, global.!ufields.!icon) == '$4' THEN DO
           /* Torrent exists but is inactive.  We can simply replace the file
            * and reuse the records.
            */
            c_record = VRMethod('CN_UPDATE', 'GetRecordAttr', records.i, 'UserData')
        END
        ELSE DO
           /* Active torrent; tell the user to stop it before replacing.
            */
            CALL VRMessage VRWindow(), 'Torrent' FILESPEC('NAME', open_filespec )     ||,
                           ' is already running.  If you wish to replace the torrent' ||,
                           ' file, please stop the running torrent first.', 'Torrent Exists', 'E'
            RETURN ''
        END
    END

    /* If the user is (for some reason) opening the file from the active 
     * torrents directory itself, don't bother recopying it.
     */
    IF open_filespec <> new_filespec THEN DO

        /* Copy the torrent file to the active directory (creating if necessary).
         */
        IF VerifyDirectory( config.!torrentdir ) \= 1 THEN DO
            CALL VRMessage VRWindow(), 'Unable to create directory "'config.!torrentdir'".', 'Error', 'E'
            RETURN ''
        END

        IF global.!debug THEN SAY 'Copying' open_filespec 'to' config.!torrentdir '...'

        IF VRCopyFile( open_filespec, config.!torrentdir ) \= 1 THEN DO
            errtext = VRError()
            CALL VRMessage VRWindow(), 'Failed to copy torrent file.' ||,
                                       '0d0a0d0a'x || errtext, 'Error', 'E'
            RETURN ''
        END

        /* Delete the original file if configured to do so.
         */
        IF config.!deleteorg == 1 THEN
            CALL VRDeleteFile open_filespec

    END

    /* Create a new container record if necessary.
     */
    IF u_record == '' THEN DO
        c_record = VRMethod("CN_TORRENTS", "AddRecord",,, new_filespec, '$4')
        u_record = VRMethod("CN_UPDATE",   "AddRecord",,, new_filespec, '$4')
        CALL VRMethod 'CN_TORRENTS', 'SetRecordAttr', c_record, 'UserData', u_record
        CALL VRMethod 'CN_UPDATE',   'SetRecordAttr', u_record, 'UserData', c_record
        IF global.!debug == 1 THEN
            SAY 'Created record' c_record '('u_record') for opened file' new_filespec
    END
    ELSE DO
        CALL VRMethod 'CN_TORRENTS', 'SetRecordAttr', c_record, 'Caption', new_filespec
        CALL VRMethod 'CN_UPDATE',   'SetRecordAttr', u_record, 'Caption', new_filespec
        CALL VRMethod 'CN_TORRENTS', 'SetRecordAttr', c_record, 'Icon', '$4'
        CALL VRMethod 'CN_UPDATE',   'SetRecordAttr', u_record, 'Icon', '$4'
        IF global.!debug == 1 THEN
            SAY 'Updated record' c_record '('u_record') for opened file' new_filespec
    END
    IF c_record == '' | u_record == '' THEN RETURN ''

    /* Now update the record fields.
     */
    CALL VRMethod 'CN_TORRENTS', 'SetFieldData', c_record,,
                  global.!fields.!name,     FILESPEC('NAME', new_filespec ),,
                  global.!fields.!icon,     '$4',,
                  global.!fields.!size,     '',,
                  global.!fields.!ipaddr,   '',,
                  global.!fields.!x_socket, 0
    CALL VRMethod 'CN_UPDATE', 'SetFieldData', u_record,,
                  global.!ufields.!name,       new_filespec,,
                  global.!ufields.!icon,       '$4',,
                  global.!ufields.!size,       '',,
                  global.!ufields.!ipaddr,     'localhost',,
                  global.!ufields.!x_socket,   0

    CALL VRMethod 'CN_TORRENTS', 'SetFieldData', c_record, global.!fields.!status,  ''
    CALL VRMethod 'CN_UPDATE',   'SetFieldData', u_record, global.!ufields.!status, ''

    CALL VRMethod 'CN_TORRENTS', 'SortRecords'

RETURN u_record

/*:VRX         PB_ABOUTOK_Click
*/
PB_ABOUTOK_Click:
    CALL SW_ABOUT_Close
RETURN

/*:VRX         PB_CTADDTRK_Click
*/
PB_CTADDTRK_Click: PROCEDURE
    address = STRIP( VRGet('EF_CTTRACKERS', 'Value'))
    IF address == '' THEN RETURN

    CALL VRMethod 'LB_CTTRACKERS', 'AddString', address
    CALL VRSet 'EF_CTTRACKERS', 'Value', ''
    items = VRGet('LB_CTTRACKERS', 'Count')
    IF items > 9 THEN
        CALL VRSet 'PB_CTADDTRK', 'Enabled', 0
    IF items > 0 THEN
        CALL VRSet 'PB_CTDELTRK', 'Enabled', 1
RETURN

/*:VRX         PB_CTCANCEL_Click
*/
PB_CTCANCEL_Click:
    CALL SW_CTORRENT_Close
return

/*:VRX         PB_CTDELTRK_Click
*/
PB_CTDELTRK_Click: PROCEDURE
    address = VRGet('LB_CTTRACKERS', 'Selected')
    IF address == 0 THEN RETURN

    CALL VRMethod 'LB_CTTRACKERS', 'Delete', address
    CALL VRSet 'EF_CTTRACKERS', 'Value', ''
    items = VRGet('LB_CTTRACKERS', 'Count')
    IF items < 10 THEN
        CALL VRSet 'PB_CTADDTRK', 'Enabled', 1
    IF items < 1 THEN
        CALL VRSet 'PB_CTDELTRK', 'Enabled', 0
RETURN

/*:VRX         PB_CTOK_Click
*/
PB_CTOK_Click:
    _ctorrent = VRGet('EF_CTEXE',    'Value')
    _ctcsport = VRGet('SPIN_CTPORT', 'Value')

    IF STRIP( _ctorrent ) == '' THEN DO
        CALL VRMessage 'SW_CTORRENT', 'No executable specified.', 'Error', 'E'
        RETURN
    END
    IF ( _ctcsport == '' | _ctcsport < 1025 | _ctcsport > 65535 ) THEN DO
        CALL VRMessage 'SW_CTORRENT', 'Port must be in the range 1025-65535.', 'Error', 'E'
        RETURN
    END

    ok = VRMethod('LB_CTTRACKERS', 'GetStringList', 'trackers.')
    IF ok == 1 THEN DO
        global.!defaults.!trackers.0 = trackers.0
        IF global.!defaults.!trackers.0 > 10 THEN
            global.!defaults.!trackers.0 = 10
        DO i = 1 TO global.!defaults.!trackers.0
            global.!defaults.!trackers.i = trackers.i
        END
    END

    _convertcp = VRGet('CHK_CTCONVERT', 'Set')

    IF VRGet('CHK_CTCACHE', 'Set') == 1 THEN
        _cachesize = VRGet('SPIN_CTCACHE', 'Value')
    ELSE _cachesize = ''

    config.!ctorrent = _ctorrent
    config.!ctcsport = _ctcsport
    global.!defaults.!convertcp = _convertcp
    global.!defaults.!cachesize = _cachesize
    CALL SW_CTORRENT_Fini

RETURN

/*:VRX         PB_DIRSCANCEL_Click
*/
PB_DIRSCANCEL_Click:
    CALL SW_DIRS_Close
RETURN

/*:VRX         PB_DIRSOK_Click
*/
PB_DIRSOK_Click:
    CALL VRSet 'EF_DIRRUN',  'BackColor', '<default>'
    CALL VRSet 'EF_DIRSEED', 'BackColor', '<default>'
    CALL VRSet 'EF_DIRDEL',  'BackColor', '<default>'
    CALL VRSet 'EF_DIRSAVE', 'BackColor', '<default>'

    bad_dir = 0
    new_downloaddir = ValidateDirectoryInput('EF_DIRRUN')
    IF new_downloaddir == '' THEN
        bad_dir = 1
    new_seeddir = ValidateDirectoryInput('EF_DIRSEED')
    IF new_seeddir == '' THEN
        bad_dir = 1
    new_deldir = ValidateDirectoryInput('EF_DIRDEL')
    IF new_deldir == '' THEN
        bad_dir = 1
    new_savedir = ValidateDirectoryInput('EF_DIRSAVE')
    IF new_savedir == '' THEN
        bad_dir = 1
    IF bad_dir == 1 THEN DO
        CALL VRMessage 'SW_DIRS', 'Invalid directory specified.', 'Invalid Input', 'E'
        RETURN
    END

    dirs_changed = 1
    CALL SW_DIRS_Fini

RETURN

/*:VRX         PB_PREFSCANCEL_Click
*/
PB_PREFSCANCEL_Click:

    prefs_changed = 0
    CALL SW_PREFS_Close

RETURN

/*:VRX         PB_PREFSOK_Click
*/
PB_PREFSOK_Click:
    sortidx = VRGet('CMB_PREFSORT', 'Selected')
    SELECT
        WHEN sortidx == 1  THEN sortcol = '!name'
        WHEN sortidx == 2  THEN sortcol = '!z_kbytes'
        WHEN sortidx == 3  THEN sortcol = '!z_percent'
        WHEN sortidx == 4  THEN sortcol = '!z_seeders'
        WHEN sortidx == 5  THEN sortcol = '!z_leechers'
        WHEN sortidx == 6  THEN sortcol = '!z_dlrate'
        WHEN sortidx == 7  THEN sortcol = '!z_ulrate'
        WHEN sortidx == 8  THEN sortcol = '!z_dloaded'
        WHEN sortidx == 9  THEN sortcol = '!z_uloaded'
        WHEN sortidx == 10 THEN sortcol = '!z_ratio'
        WHEN sortidx == 11 THEN sortcol = '!z_eta'
        OTHERWISE sortcol = '!name'
    END

    IF VRGet('RB_PREFSORTD', 'Set') == 1 THEN
        sortdir = 'Descending'
    ELSE
        sortdir = 'Ascending'

    autostart = VRGet('CMB_PREFSTART', 'Selected')
    IF autostart > 1 THEN
        autodialog = VRGet('CHK_PREFDIALOG', 'Set')
    ELSE
        autodialog = 0

    onexit     = VRGet('CMB_PREFONEXIT', 'Selected')
    autoresume = VRGet('CHK_PREFRESUME', 'Set')
    IF VRGet('CHK_PREFCONFIRM', 'Enabled') == 0 THEN
        confirmquit = 0
    ELSE
        confirmquit = VRGet('CHK_PREFCONFIRM', 'Set')
    refresh = VRGet('SPIN_PREFINT', 'Value') * 1000

    confirmseed = VRGet('CHK_PREFSEEDCONF', 'Set')
    deleteorg   = VRGet('CHK_PREFDELORG',   'Set')

    prefs_changed = 1
    CALL SW_PREFS_Close

RETURN

/*:VRX         PB_STARTCANCEL_Click
*/
PB_STARTCANCEL_Click:
    CALL SW_START_Close
RETURN

/*:VRX         PB_STARTOK_Click
*/
PB_STARTOK_Click: PROCEDURE EXPOSE global. config. filefields. started

    ok = ApplyStartOptions()
    IF ok \= 0 THEN RETURN 1

    started = 0
    rc = RunCTorrent()
    IF rc == 0 THEN started = 1

    CALL SW_START_Close

RETURN 0

/*:VRX         PB_STARTSET_Click
*/
PB_STARTSET_Click: PROCEDURE EXPOSE global. config. filefields. started

    started = 0
    ok = ApplyStartOptions()
    IF ok \= 0 THEN RETURN 1
    CALL SW_START_Close

RETURN 0

/*:VRX         ProfileLoad
*/
ProfileLoad: PROCEDURE EXPOSE global. config.

    os2_ini = VALUE('USER_INI',,'OS2ENVIRONMENT')
    inipath = VRParseFilePath( os2_ini, 'DP')
    IF inipath == '' THEN inipath = SysBootDrive() || '\OS2'

    config.!ini = inipath'\pmfact.ini'
    IF STREAM( config.!ini, 'C', 'QUERY EXISTS') == '' THEN DO
        CALL VRMethod VRWindow(), 'CenterWindow'
        CALL VRSet 'CN_TORRENTS', 'SplitBarLeft', 2500
        RETURN
    END

    /* Position and size settings
     */
    _xpos = VRGetIni('Window', 'XPos',   config.!ini, 'NoClose')
    _ypos = VRGetIni('Window', 'YPos',   config.!ini, 'NoClose')
    _cx   = VRGetIni('Window', 'Width',  config.!ini, 'NoClose')
    _cy   = VRGetIni('Window', 'Height', config.!ini, 'NoClose')
    _sbl  = VRGetIni('Window', 'Split',  config.!ini, 'NoClose')
    IF _xpos == '' THEN _xpos = -1
    IF _ypos == '' THEN _ypos = -1
    IF _cx   == '' THEN _cx   = 0
    IF _cy   == '' THEN _cy   = 0
    IF _sbl  == '' THEN _sbl  = 3000

    /* Font and colour settings
     */
    _cnrfont = VRGetIni('Preferences', 'ContainerFont', config.!ini, 'NoClose')
    _cnrbg   = VRGetIni('Preferences', 'ContainerBG',   config.!ini, 'NoClose')
    _cnrfg   = VRGetIni('Preferences', 'ContainerFG',   config.!ini, 'NoClose')
    IF _cnrfont == '' THEN _cnrfont = '9.WarpSans'
    IF _cnrbg == ''   THEN _cnrbg   = 'SystemWindow'
    IF _cnrfg == ''   THEN _cnrfg   = 'SystemWindowText'

    /* CTorrent and CTCS settings
     */
    _ctorrent = VRGetIni('CTorrent', 'Exe',  config.!ini, 'NoClose')
    _ctcsport = VRGetIni('CTorrent', 'Port', config.!ini, 'NoClose')
    IF _ctorrent \= '' THEN config.!ctorrent = _ctorrent
    IF _ctcsport \= '' THEN config.!ctcsport = _ctcsport
    _tracklist = STRIP( VRGetIni('CTorrent', 'PrefTrackers', config.!ini, 'NoClose'))
    IF _tracklist \= '' THEN DO i = 1 TO WORDS( _tracklist )
        global.!defaults.!trackers.i = WORD( _tracklist, i )
        global.!defaults.!trackers.0 = global.!defaults.!trackers.0 + 1
    END
    _convertcp = VRGetIni('CTorrent', 'ConvertCP', config.!ini, 'NoClose')
    _cachesize = VRGetIni('CTorrent', 'CacheSize', config.!ini, 'NoClose')
    IF _convertcp \= '' THEN global.!defaults.!convertcp = _convertcp
    IF _cachesize \= '' THEN global.!defaults.!cachesize = _cachesize

    /* Preferences
     */
    _sortcolumn  = VRGetIni('Preferences', 'SortColumn',      config.!ini, 'NoClose')
    _sorttype    = VRGetIni('Preferences', 'SortType',        config.!ini, 'NoClose')
    _autostart   = VRGetIni('Preferences', 'AutoStart',       config.!ini, 'NoClose')
    _startdlg    = VRGetIni('Preferences', 'AutoDialog',      config.!ini, 'NoClose')
    _onexit      = VRGetIni('Preferences', 'OnExit',          config.!ini, 'NoClose')
    _confirmexit = VRGetIni('Preferences', 'ConfirmExit',     config.!ini, 'NoClose')
    _confirmseed = VRGetIni('Preferences', 'ConfirmSeed',     config.!ini, 'NoClose')
    _autoresume  = VRGetIni('Preferences', 'AutoResume',      config.!ini, 'NoClose')
    _refreshint  = VRGetIni('Preferences', 'RefreshInterval', config.!ini, 'NoClose')
    _deleteorg   = VRGetIni('Preferences', 'DeleteOriginal',  config.!ini, 'NoClose')
    IF _sortcolumn  \= '' THEN config.!sortcolumn  = _sortcolumn
    IF _sorttype    \= '' THEN config.!sorttype    = _sorttype
    IF _autostart   \= '' THEN config.!autostart   = _autostart
    IF _startdlg    \= '' THEN config.!autodialog  = _startdlg
    IF _onexit      \= '' THEN config.!onexit      = _onexit
    IF _confirmexit \= '' THEN config.!confirmexit = _confirmexit
    IF _confirmseed \= '' THEN config.!confirmseed = _confirmseed
    IF _autoresume  \= '' THEN config.!autoresume  = _autoresume
    IF _refreshint  \= '' THEN config.!interval    = _refreshint
    IF _deleteorg   \= '' THEN config.!deleteorg   = _deleteorg

    /* Directory settings
     */
    _lastdir    = VRGetIni('Paths', 'LastOpen', config.!ini, 'NoClose')
    _torrentdir = VRGetIni('Paths', 'Active',   config.!ini, 'NoClose')
    _seeddir    = VRGetIni('Paths', 'Seeding',  config.!ini, 'NoClose')
    _deldir     = VRGetIni('Paths', 'Removed',  config.!ini, 'NoClose')
    _savedir    = VRGetIni('Paths', 'Download', config.!ini )

    IF _torrentdir \= '' THEN
        IF VRExpandFileName( _torrentdir ) \= '' THEN config.!torrentdir = _torrentdir
    IF _seeddir \= '' THEN
        IF VRExpandFileName( _seeddir ) \= '' THEN config.!seeddir = _seeddir
    IF _deldir \= '' THEN
        IF VRExpandFileName( _deldir ) \= '' THEN config.!deldir = _deldir
    IF _savedir \= '' THEN
        IF VRExpandFileName( _savedir ) \= '' THEN config.!downloaddir = _savedir
    IF _lastdir \= '' THEN
        IF VRExpandFileName( _lastdir ) \= '' THEN config.!opendir = _lastdir


    /* Apply the settings
     */
    CALL VRSet 'CN_TORRENTS', 'SplitBarLeft', _sbl
    CALL VRSet 'CN_TORRENTS', 'Font',      _cnrfont
    CALL VRSet 'CN_TORRENTS', 'BackColor', _cnrbg
    CALL VRSet 'CN_TORRENTS', 'ForeColor', _cnrfg

    CALL VRSet 'TM_REFRESH',  'Delay', config.!interval

    IF ( _cx > 0 ) & ( _cy > 0 ) THEN DO
        CALL VRSet 'WN_MAIN', 'Width',  _cx
        CALL VRSet 'WN_MAIN', 'Height', _cy
    END

    IF ( _xpos >= 0 ) & ( _ypos >= 0 ) THEN DO
        CALL VRSet 'WN_MAIN', 'Left', _xpos
        CALL VRSet 'WN_MAIN', 'Top',  _ypos
    END
    ELSE
        CALL VRMethod VRWindow(), 'CenterWindow'

RETURN

/*:VRX         ProfileSave
*/
ProfileSave: PROCEDURE EXPOSE global. config.
    _cnrfont = VRGet('CN_TORRENTS', 'Font')
    _cnrbg   = VRGet('CN_TORRENTS', 'BackColor')
    _cnrfg   = VRGet('CN_TORRENTS', 'ForeColor')

    _xpos = VRGet('WN_MAIN', 'Left')
    _ypos = VRGet('WN_MAIN', 'Top')
    _cx   = VRGet('WN_MAIN', 'Width')
    _cy   = VRGet('WN_MAIN', 'Height')
    _sbl  = VRGet('CN_TORRENTS', 'SplitBarLeft')

    CALL VRSetIni 'CTorrent', 'Exe',  config.!ctorrent, config.!ini, 'NoClose'
    CALL VRSetIni 'CTorrent', 'Port', config.!ctcsport, config.!ini, 'NoClose'

    ptlist = ''
    DO i = 1 TO global.!defaults.!trackers.0
        ptlist = ptlist || global.!defaults.!trackers.i || ' '
    END
    CALL VRSetIni 'CTorrent', 'PrefTrackers', ptlist, config.!ini, 'NoClose'

    CALL VRSetIni 'CTorrent', 'ConvertCP', global.!defaults.!convertcp, config.!ini, 'NoClose'
    CALL VRSetIni 'CTorrent', 'CacheSize', global.!defaults.!cachesize, config.!ini, 'NoClose'

    CALL VRSetIni 'Preferences', 'SortColumn',     config.!sortcolumn,  config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'SortType',       config.!sorttype,    config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'AutoStart',      config.!autostart,   config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'AutoDialog',     config.!autodialog,  config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'AutoResume',     config.!autoresume,  config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'OnExit',         config.!onexit,      config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'ConfirmExit',    config.!confirmexit, config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'ConfirmSeed',    config.!confirmseed, config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'RefreshInterval',config.!interval,    config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'DeleteOriginal', config.!deleteorg,   config.!ini, 'NoClose'

    CALL VRSetIni 'Preferences', 'ContainerFont', _cnrfont, config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'ContainerBG',   _cnrbg,   config.!ini, 'NoClose'
    CALL VRSetIni 'Preferences', 'ContainerFG',   _cnrfg,   config.!ini, 'NoClose'

    CALL VRSetIni 'Paths', 'LastOpen', config.!opendir,     config.!ini, 'NoClose'
    CALL VRSetIni 'Paths', 'Active',   config.!torrentdir,  config.!ini, 'NoClose'
    CALL VRSetIni 'Paths', 'Seeding',  config.!seeddir,     config.!ini, 'NoClose'
    CALL VRSetIni 'Paths', 'Removed',  config.!deldir,      config.!ini, 'NoClose'
    CALL VRSetIni 'Paths', 'Download', config.!downloaddir, config.!ini, 'NoClose'

    CALL VRSetIni 'Window', 'XPos',   _xpos, config.!ini, 'NoClose'
    CALL VRSetIni 'Window', 'YPos',   _ypos, config.!ini, 'NoClose'
    CALL VRSetIni 'Window', 'Width',  _cx,   config.!ini, 'NoClose'
    CALL VRSetIni 'Window', 'Height', _cy,   config.!ini, 'NoClose'
    CALL VRSetIni 'Window', 'Split',  _sbl,  config.!ini

RETURN

/*:VRX         Quit
*/
Quit:
    CALL ProfileSave
    CALL VRSet 'WN_MAIN', 'Pointer', '<default>'

    window = VRWindow()
    call VRSet window, "Shutdown", 1
    drop window

RETURN

/*:VRX         QuitWait
*/
QuitWait: PROCEDURE EXPOSE global. config.
    /* Called when the user selects to quit.  The actual Quit function will be
     * signalled when the client thread finishes.
     */

    action = ConfirmStop()
    /* Action 1: Stop applicable torrents (if configured to do so) and then exit
     * Action 2: Do not stop torrents, just exit
     * Action 3: Cancel (do not exit)
     */
    IF action == 3 THEN RETURN

    CALL VRSet 'WN_MAIN', 'Pointer', 'WAIT'
    CALL VRSet 'WN_MAIN', 'Caption', 'FrontenACT - Closing Connections ...'
    CALL VRMethod 'Application', 'PostQueue', global.!listen_thread, 0, 'finished = 1'

    IF action == 1 THEN DO
        rc = VRMethod('Application', 'PostQueue', global.!client_thread, 0, 'CALL Shutdown' config.!onexit )
        IF VRMethod("CN_TORRENTS", "GetRecordList", "All", "recs.") == 1 THEN DO i = 1 TO recs.0
            _client = VRMethod('CN_TORRENTS', 'GetFieldData', recs.i, global.!fields.!x_socket )
            IF _client > 0 THEN DO
                CALL VRMethod 'CN_UPDATE', 'SetFieldData', global.!updrecs._client,,
                                           global.!ufields.!status, 'Stopping...'
                CALL VRMethod 'CN_TORRENTS', 'SetFieldData', recs.i,,
                                             global.!fields.!status, 'Stopping...'
            END
        END
    END
    ELSE
        rc = VRMethod('Application', 'PostQueue', global.!client_thread, 0, 'finished = 1')

    /* If we couldn't contact the client thread, just quit straight away.
     */
    IF rc == 0 THEN CALL Quit

RETURN

/*:VRX         RefreshDisplay
*/
RefreshDisplay: PROCEDURE EXPOSE global.

    IF VRMethod("CN_UPDATE", "GetRecordList", "All", "urecs.") \= 1 THEN
        RETURN 1

    CALL VRSet 'CN_TORRENTS', 'Painting', 0
    DO i = 1 TO urecs.0

        ok = VRMethod('CN_UPDATE', 'GetFieldData', urecs.i, 'items.')
        IF items.0 < 14 THEN ITERATE

        _icon     = items.1
        _name     = items.2
        _size     = items.3
        _pieces   = items.4
        _seeders  = items.5
        _leechers = items.6
        _dlrate   = items.7
        _ulrate   = items.8
        _dltotal  = items.9
        _ultotal  = items.10
        _marks    = items.11
        _status   = items.12
        _ipaddr   = items.13
        _socket   = items.14

        IF ( _socket == '') | ( SYMBOL('global.!records._socket') == 'LIT') THEN DO
            v_record = VRMethod('CN_UPDATE', 'GetRecordAttr', urecs.i, 'UserData')
            active = 0
        END
        ELSE DO
            v_record = global.!records._socket
            active = 1
        END

        IF active == 0 THEN DO
            /* Not a running torrent; just set the icon, name, and status
             * fields, and blank out the rest.
             */
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!icon,   _icon,,
                          global.!fields.!name,   FILESPEC('NAME', _name ),,
                          global.!fields.!size,   '',,
                          global.!fields.!status,  _status
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!seeders,  '',,
                          global.!fields.!leechers, '',,
                          global.!fields.!dlrate,   '',,
                          global.!fields.!ulrate,   ''
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!dloaded, '',,
                          global.!fields.!uloaded, '',,
                          global.!fields.!ratio,   '',,
                          global.!fields.!pieces,  ''
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!eta, ''

            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!z_percent,  0,,
                          global.!fields.!z_kbytes,   0,,
                          global.!fields.!z_seeders,  0,,
                          global.!fields.!z_leechers, 0
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!z_dlrate,  0,,
                          global.!fields.!z_ulrate,  0,,
                          global.!fields.!z_dloaded, 0,,
                          global.!fields.!z_uloaded, 0
            CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                          global.!fields.!x_socket, 0,,
                          global.!fields.!z_ratio,  0,,
                          global.!fields.!z_eta,    0

            ITERATE
        END

        /* Calculate the percent completion.
         */
        PARSE VAR _pieces _have '/' _avail '/' _total
        _percent = '?'
        _perthou = 0
        IF Utils('IsNumber', _have ) & Utils('IsPositiveNumber', _total ) THEN DO
            _percent = FORMAT( (_have * 100) / _total,, 1 )
            _perthou = FORMAT( (_have * 1000) / _total,, 0 )
            IF (( _percent == '100.0') & ( _have < _total )) THEN DO
                _percent = '>99.9'
                _perthou = 999
            END
            ELSE IF (( _percent == '0.0') & ( _have > 0 )) THEN DO
                _percent = '<0.1'
                _perthou = 1
            END
        END

        /* Calculate the sharing ratio.
         */
        _ratio   = '-'
        _iratio = 0
        IF Utils('IsNumber', _ultotal ) & Utils('IsNumber', _dltotal ) THEN DO
            IF _ultotal < 1 THEN NOP
            ELSE IF _dltotal < 1 THEN _ratio = '*'
            ELSE DO
                _ratio = FORMAT( _ultotal / _dltotal,, 1 )
                _iratio = _ratio * 10
            END
        END

        /* Calculate the estimated time remaining
         */
        _eta = 0
        _etatxt = '*'
        _nmarks = WORDS( _marks )
        IF _perthou == 1000 THEN
            _etatxt = '0:00:00'
        ELSE IF _nmarks > 0 THEN DO
            _aggrate = 0
            DO j = 1 TO _nmarks
                _tm = WORD( _marks, j )
                IF Utils('IsNumber', _tm ) THEN
                    _aggrate = _aggrate + _tm
                ELSE
                    _nmarks = _nmarks - 1
            END
            _avgrate = _aggrate / _nmarks
            IF ( _avgrate >= 1 ) & Utils('IsNumber', _dltotal ) & Utils('IsNumber', _size ) THEN DO
                _bytesleft = (_size - _dltotal)
                IF ( _bytesleft == 0 ) & ( _perthou < 1000 ) THEN
                     _bytesleft = 524288
                IF _bytesleft > 0 THEN DO
                    _eta = FORMAT( _bytesleft / _avgrate,, 0 )
                    _etatxt = Utils('ConvertSeconds', _eta )
                END
                ELSE _etatxt = '0:00:00'
            END
        END

        /* Get the size field values.
         */
        IF Utils('IsNumber', _size ) THEN DO
            _sizetxt = Utils('ConvertBytes', _size )
            _isize = _size
        END
        ELSE DO
            _sizetxt = '...'
            _isize = 0
        END

        /* Get the other numeric field values.
         */
        _iseeders  = 0
        _ileechers = 0
        PARSE VAR _seeders  _act_seeders .
        PARSE VAR _leechers _act_leechers .
        IF Utils('IsNumber', _act_seeders ) THEN
            _iseeders = _act_seeders
        IF Utils('IsNumber', _act_leechers ) THEN
            _ileechers = _act_leechers

        /* Update the visible fields */
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!icon,   _icon,,
                      global.!fields.!name,   FILESPEC('NAME', _name ),,
                      global.!fields.!size,   _sizetxt,,
                      global.!fields.!pieces, _percent
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!seeders,  _seeders,,
                      global.!fields.!leechers, _leechers,,
                      global.!fields.!dlrate,   Utils('ConvertBytes', _dlrate ) || '/s',,
                      global.!fields.!ulrate,   Utils('ConvertBytes', _ulrate ) || '/s'
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!dloaded, Utils('ConvertBytes', _dltotal ),,
                      global.!fields.!uloaded, Utils('ConvertBytes', _ultotal ),,
                      global.!fields.!ratio,   _ratio,,
                      global.!fields.!status,  _status
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!eta, _etatxt

        /* Now update the hidden fields */
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!z_percent,  _perthou,,
                      global.!fields.!z_kbytes,   _isize,,
                      global.!fields.!z_seeders,  _iseeders,,
                      global.!fields.!z_leechers, _ileechers
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!z_dlrate,  _dlrate,,
                      global.!fields.!z_ulrate,  _ulrate,,
                      global.!fields.!z_dloaded, _dltotal,,
                      global.!fields.!z_uloaded, _ultotal
        CALL VRMethod 'CN_TORRENTS', 'SetFieldData', v_record,,
                      global.!fields.!z_ratio,  _iratio,,
                      global.!fields.!z_eta,    _eta,,
                      global.!fields.!x_socket, _socket

    END
    CALL VRMethod 'CN_TORRENTS', 'SortRecords'
    CALL VRSet 'CN_TORRENTS', 'Painting', 1
    CALL UpdateMenuItems

RETURN 0

/*:VRX         RefreshFiles
*/
RefreshFiles: PROCEDURE EXPOSE global. config.

    /* Scan the active and seeding torrent directories: add any files without
     * records, and remove any local records without files.
     */
    CALL VRMethod 'CN_TORRENTS', 'GetRecordList', 'All', 'records.'

    tor_active.0 = 0
    tor_seeding.0 = 0
    ok = SysFileTree( config.!torrentdir'\*', 'tor_active.', 'FO')
    ok = SysFileTree( config.!seeddir'\*', 'tor_seeding.', 'FO')
    DO i = 1 TO tor_active.0
        IF TRANSLATE( RIGHT( torfiles.i, 3 )) == '.BF' THEN ITERATE
        IF IsTorrent( torfiles.i ) == 0 THEN ITERATE

        /* TODO implement this */
    END

RETURN

/*:VRX         RunCTorrent
*/
RunCTorrent:

    /* Make sure the selected download path exists.
     */
    IF VerifyDirectory( dl_dir ) \= 1 THEN DO
        CALL VRMessage VRWindow(), 'Failed to create target directory "'dl_dir'".', 'Error', 'E'
        RETURN 3
    END

    /* Change to the download directory.
     */
    IF TRANSLATE( DIRECTORY( dl_dir )) \= TRANSLATE( dl_dir ) THEN DO
        CALL VRMessage VRWindow(), 'Failed to change to directory "'dl_dir'".', 'Error', 'E'
        RETURN 3
    END

    /* Now start the torrent.
     */
    IF global.!debug == 1 THEN DO
        SAY 'Starting torrent:' torrent 
        SAY ' - Command: ' run_command '"'torrent'"'
        SAY ' - Location:' DIRECTORY()
    END
    ADDRESS CMD '@' run_command '"'torrent'" 2>con 1>con'

    IF global.!debug == 1 THEN SAY 'Program return code =' rc

RETURN rc

/*:VRX         SetContainerSort
*/
SetContainerSort: PROCEDURE EXPOSE config. global.
    CALL VRSet 'CN_TORRENTS', 'DetailSort', VALUE('global.!fields.' || config.!sortcolumn )
    CALL VRSet 'CN_TORRENTS', 'Sort', config.!sorttype
    CALL VRMethod 'CN_TORRENTS', 'SortRecords'
RETURN

/*:VRX         SetupContainer
*/
SetupContainer: PROCEDURE EXPOSE global.

    _dn = Utils('DownloadSymbol')
    IF _dn == '' THEN _dn = 'DL'
    _up = Utils('UploadSymbol')
    IF _up == '' THEN _up = 'UL'

    ok = VRMethod('Application', 'PutVar', '_dn', 'DLSign')
    ok = VRMethod('Application', 'PutVar', '_up', 'ULSign')

    /* Visible fields for the user */
    global.!fields.!icon     = VRMethod('CN_TORRENTS', 'AddField', 'Icon',   '')
    global.!fields.!name     = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Torrent')
    global.!fields.!ipaddr   = VRMethod('CN_TORRENTS', 'AddField', 'String', '')
    global.!fields.!size     = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Size')
    global.!fields.!pieces   = VRMethod('CN_TORRENTS', 'AddField', 'String', '% Done')
    global.!fields.!seeders  = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Seeders')
    global.!fields.!leechers = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Leechers')
    global.!fields.!dlrate   = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Speed' _dn )
    global.!fields.!ulrate   = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Speed' _up )
    global.!fields.!dloaded  = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Total' _dn )
    global.!fields.!uloaded  = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Total' _up )
    global.!fields.!ratio    = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Ratio')
    global.!fields.!eta      = VRMethod('CN_TORRENTS', 'AddField', 'String', 'ETA')
    global.!fields.!status   = VRMethod('CN_TORRENTS', 'AddField', 'String', 'Status')

    /* Hidden fields used for other associated data we don't want displayed
     */
    global.!fields.!x_socket   = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'Socket')
    /* -ALT Not really necessary as it's in CN_UPDATE...?
    global.!fields.!x_dtid     = VRMethod('CN_TORRENTS', 'AddField', 'String', 'DetailsThread')
     */

    /* Hidden fields used for sorting (because we can only sort numbers using ULong fields) */
    global.!fields.!z_percent  = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortPercent')
    global.!fields.!z_kbytes   = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortKB')
    global.!fields.!z_seeders  = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortSeeders')
    global.!fields.!z_leechers = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortLeechers')
    global.!fields.!z_dlrate   = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortSpeedDn')
    global.!fields.!z_ulrate   = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortSpeedUp')
    global.!fields.!z_dloaded  = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortTotalDn')
    global.!fields.!z_uloaded  = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortTotalUp')
    global.!fields.!z_ratio    = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortRatio')
    global.!fields.!z_eta      = VRMethod('CN_TORRENTS', 'AddField', 'ULong', 'SortETA')

    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!icon,   'VertSeparator',  0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!icon,   'HorizSeparator', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!name,   'VertSeparator',  0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!ipaddr, 'VertSeparator',  0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!ipaddr, 'HorizSeparator', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!status, 'VertSeparator',  0

    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!x_socket,   'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_percent,  'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_kbytes,   'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_seeders,  'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_leechers, 'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_dlrate,   'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_ulrate,   'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_dloaded,  'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_uloaded,  'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_ratio,    'Visible', 0
    CALL VRMethod 'CN_TORRENTS', 'SetFieldAttr', global.!fields.!z_eta,      'Visible', 0

    CALL VRSet 'CN_TORRENTS', 'LastSplitField', global.!fields.!ipaddr

    /* Fields on the hidden container that we use for real-time updates.
     * (Note: unlike CN_TORRENTS, the !name field in this container is intended
     *  to include the full path.)
     */
    global.!ufields.!icon     = VRMethod('CN_UPDATE', 'AddField', 'Icon',   '')
    global.!ufields.!name     = VRMethod('CN_UPDATE', 'AddField', 'String', 'Torrent Name')
    global.!ufields.!size     = VRMethod('CN_UPDATE', 'AddField', 'String', 'Size')
    global.!ufields.!pieces   = VRMethod('CN_UPDATE', 'AddField', 'String', 'Pieces')
    global.!ufields.!seeders  = VRMethod('CN_UPDATE', 'AddField', 'String', 'Seeders')
    global.!ufields.!leechers = VRMethod('CN_UPDATE', 'AddField', 'String', 'Leechers')
    global.!ufields.!dlrate   = VRMethod('CN_UPDATE', 'AddField', 'String', 'Speed' _dn )
    global.!ufields.!ulrate   = VRMethod('CN_UPDATE', 'AddField', 'String', 'Speed' _up )
    global.!ufields.!dloaded  = VRMethod('CN_UPDATE', 'AddField', 'String', 'Total' _dn )
    global.!ufields.!uloaded  = VRMethod('CN_UPDATE', 'AddField', 'String', 'Total' _up )
    global.!ufields.!timemark = VRMethod('CN_UPDATE', 'AddField', 'String', 'Time Marks')
    global.!ufields.!status   = VRMethod('CN_UPDATE', 'AddField', 'String', 'Status')
    global.!ufields.!ipaddr   = VRMethod('CN_UPDATE', 'AddField', 'String', 'Host')

    /* These fields (starting with !x_) don't reflect visible fields in CN_TORRENTS */
    global.!ufields.!x_socket = VRMethod('CN_UPDATE', 'AddField', 'ULong',  'Socket')
    global.!ufields.!x_dtid   = VRMethod('CN_UPDATE', 'AddField', 'ULong',  'DetailsThread')

RETURN

/*:VRX         SetupDefaults
*/
SetupDefaults:

    me = VRGet('Application', 'Program')
    config.!mydir = VRParseFilePath( me, 'DP')
    IF config.!mydir == '' THEN config.!mydir = DIRECTORY()

    config.!ctorrent      = 'act.exe'
    config.!ctcsport      = 2780
    config.!torrentdir    = config.!mydir'\RUNNING'
    config.!seeddir       = config.!mydir'\SEEDING'
    config.!deldir        = config.!mydir'\REMOVED'
    config.!downloaddir   = config.!mydir'\DOWNLOAD'
    config.!opendir       = config.!mydir
    config.!sortcolumn    = '!name'
    config.!sorttype      = 'Ascending'
    config.!autoresume    = 0
    config.!onexit        = 2
    config.!confirmexit   = 1
    config.!autostart     = 2
    config.!autodialog    = 1
    config.!interval      = 5000
    config.!confirmseed   = 1
    config.!deleteorg     = 0

    /* Basic options, can be overridden per torrent on the startup dialog */
    global.!defaults.!trackers.0  = 0
    global.!defaults.!convertcp   = 0
    global.!defaults.!cachesize   = ''

    /* Advanced options (not implemented yet) */
    global.!defaults.!seedtime    = 72
    global.!defaults.!seedratio   = 1
    global.!defaults.!maxpeers    = 30
    global.!defaults.!minpeers    = 1
    global.!defaults.!maxupload   = 250
    global.!defaults.!maxdownload = 0
    global.!defaults.!maxcache    = 16
    global.!defaults.!port        = 2706
    global.!defaults.!interface   = 0
    global.!defaults.!publicip    = ''
    global.!defaults.!peerid      = ''
    global.!defaults.!useragent   = ''

RETURN 0

/*:VRX         SetupLocale
*/
SetupLocale:

    PARSE VALUE VRGetIni('PM_National', 'iDate',     'User', 'NoClose') WITH iDate '00'x .
    PARSE VALUE VRGetIni('PM_National', 'iTime',     'User', 'NoClose') WITH iTime '00'x .
    PARSE VALUE VRGetIni('PM_National', 's1159',     'User', 'NoClose') WITH s1159 '00'x .
    PARSE VALUE VRGetIni('PM_National', 's2359',     'User', 'NoClose') WITH s2359 '00'x .
    PARSE VALUE VRGetIni('PM_National', 'sDecimal',  'User', 'NoClose') WITH sDecimal 2 .
    PARSE VALUE VRGetIni('PM_National', 'sThousand', 'User')            WITH sThousand 2 .

    sDay = 'day'
    sDays = 'days'

    CALL VRMethod 'Application', 'PutVar', 'iDate'
    CALL VRMethod 'Application', 'PutVar', 'iTime'
    CALL VRMethod 'Application', 'PutVar', 's1159'
    CALL VRMethod 'Application', 'PutVar', 's2359'
    CALL VRMethod 'Application', 'PutVar', 'sDecimal'
    CALL VRMethod 'Application', 'PutVar', 'sThousand'
    CALL VRMethod 'Application', 'PutVar', 'sDay'
    CALL VRMethod 'Application', 'PutVar', 'sDays'

RETURN

/*:VRX         StartTorrent
*/
StartTorrent: PROCEDURE EXPOSE global. config.
    PARSE ARG urecord

    crecord = VRMethod('CN_UPDATE', 'GetRecordAttr', urecord, 'UserData')
    torrent = VRMethod('CN_UPDATE', 'GetFieldData', urecord, global.!ufields.!name )
    IF torrent == '' THEN RETURN 2

    /* If the torrent already has its command-line defined, this is a resume
     * operation -- so just get the saved command line and restart the torrent.
     */
    run_command = ''
    ok = SysGetEA( torrent, 'PMFACT.Command', 'eadata')
    IF ok == 0 THEN DO
        PARSE VAR eadata 1 _type 3 . 5 _cmdline
        IF C2X( _type ) == 'FDFF' THEN run_command = _cmdline
    END

    /* Otherwise, treat it as a new torrent.
     */
    IF run_command == '' THEN DO

        /* If configured to show the start options dialog, do so and then
         * return.
         */
        IF config.!autodialog == 1 THEN DO
            old_cmdline = ''
            old_savedir = ''
            CALL VRLoadSecondary 'SW_START', 'W'
            CALL UpdateMenuItems
            IF started == 1 THEN DO
                CALL VRMethod 'CN_TORRENTS', 'SetFieldData', crecord,,
                              global.!fields.!icon,   '$2',,
                              global.!fields.!status, 'Starting...'
                CALL VRMethod 'CN_UPDATE', 'SetFieldData', urecord,,
                              global.!ufields.!icon,   '$2',,
                              global.!ufields.!status, 'Starting...'
            END
            RETURN 0
        END

        /* Otherwise, we will auto-start the torrent using default options.
         */
        ct_name = TRANSLATE( VRParseFilePath( config.!ctorrent, 'N'))
        ctparms = '-d -S localhost:'config.!ctcsport
        IF ( ct_name == 'ACT') THEN DO
            IF global.!defaults.!convertcp == 0 THEN ctparms = ctparms '-utf'
            ctparms = ctparms '-fenc 1208'
        END

        /* Search the torrent's trackers for one of our preferred trackers.
         */
        IF ct_name \= 'CTORRENT9' THEN DO
            CALL GetTorrentContents torrent
            foundtracker = 0
            DO i = 1 TO global.!defaults.!trackers.0
                DO j = 1 TO trackers.0
                    IF TRANSLATE( trackers.j ) == TRANSLATE( global.!defaults.!trackers.i ) THEN DO
                        foundtracker = j
                        LEAVE
                    END
                END
                IF foundtracker > 0 THEN LEAVE
            END
            IF foundtracker > 0 THEN
                ctparms = ctparms '-u' foundtracker
        END

        run_command = config.!ctorrent ctparms

        /* Save the command-line to the EAs.
         */
        lenbytes = X2C( D2X( LENGTH( run_command ), 4 ))
        eabytes  = X2C('FDFF') || REVERSE( lenbytes ) || run_command
        ok = SysPutEA( torrent, 'PMFACT.Command', eabytes )
        IF ok \= 0 THEN DO
            CALL VRMessage VRWindow(), 'Failed to save torrent file attributes.  SysPutEA returned' ok'.', 'Error', 'E'
            RETURN 1
        END

    END

    /* Try and get the target download directory.  If not defined, use the
     * default path and write it to the EAs (this should only occur for
     * new torrents as well, but it doesn't hurt to always check).
     */
    dl_dir = ''
    ok = SysGetEA( torrent, 'PMFACT.SavePath', 'eadata')
    IF ok == 0 THEN DO
        PARSE VAR eadata 1 _type 3 . 5 _savepath
        IF C2X( _type ) == 'FDFF' THEN dl_dir = _savepath
    END
    IF dl_dir == '' THEN DO
        dl_dir = config.!downloaddir
        lenbytes = X2C( D2X( LENGTH( dl_dir ), 4 ))
        eabytes  = X2C('FDFF') || REVERSE( lenbytes ) || dl_dir
        ok = SysPutEA( torrent, 'PMFACT.SavePath', eabytes )
        IF ok \= 0 THEN DO
            CALL VRMessage VRWindow(), 'Failed to set torrent file attributes.  SysPutEA returned' ok'.', 'Error', 'E'
            RETURN 1
        END
    END

    /* Add the '-f' flag if appropriate (if the torrent is in the 'seeding'
     * directory, OR (TODO) if a bitfield file exists.
     */
    which_dir = TRANSLATE( VRParseFileName( torrent, 'DP'))
    IF which_dir == TRANSLATE( options.!seeddir ) THEN
        IF WORDPOS('-f', run_command ) == 0 THEN
            run_command = run_command '-f'

    rc = RunCTorrent()

    CALL VRMethod 'CN_TORRENTS', 'SetFieldData', crecord,,
                  global.!fields.!icon,   '$2',,
                  global.!fields.!status, 'Starting...'
    CALL VRMethod 'CN_UPDATE', 'SetFieldData', urecord,,
                  global.!ufields.!icon,   '$2',,
                  global.!ufields.!status, 'Starting...'

RETURN rc

/*:VRX         SW_ABOUT_Close
*/
SW_ABOUT_Close:
    call SW_ABOUT_Fini
return

/*:VRX         SW_ABOUT_Create
*/
SW_ABOUT_Create:
    call SW_ABOUT_Init
return

/*:VRX         SW_ABOUT_Fini
*/
SW_ABOUT_Fini:
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         SW_ABOUT_Init
*/
SW_ABOUT_Init:
    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window
return

/*:VRX         SW_CTORRENT_Close
*/
SW_CTORRENT_Close:
    call SW_CTORRENT_Fini
return

/*:VRX         SW_CTORRENT_Create
*/
SW_CTORRENT_Create:
    call SW_CTORRENT_Init
return

/*:VRX         SW_CTORRENT_Fini
*/
SW_CTORRENT_Fini:
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         SW_CTORRENT_Init
*/
SW_CTORRENT_Init:

    CALL VRSet 'EF_CTEXE',    'Value', config.!ctorrent
    CALL VRSet 'SPIN_CTPORT', 'Value', config.!ctcsport

    DO i = 1 TO global.!defaults.!trackers.0
        IF i > 10 THEN LEAVE
        CALL VRMethod 'LB_CTTRACKERS', 'AddString', global.!defaults.!trackers.i
    END
    IF global.!defaults.!trackers.0 > 0 THEN
        CALL VRSet 'PB_CTDELTRK', 'Enabled', 1
    IF global.!defaults.!convertcp == 0 THEN
        CALL VRSet 'CHK_CTCONVERT', 'Set', 0
    ELSE
        CALL VRSet 'CHK_CTCONVERT', 'Set', 1

    IF global.!defaults.!cachesize <> '' THEN DO
        CALL VRSet 'CHK_CTCACHE', 'Set', 1
        CALL VRSet 'SPIN_CTCACHE', 'Enabled', 1
        CALL VRSet 'SPIN_CTCACHE', 'Value',   global.!defaults.!cachesize
    END
    ELSE
        CALL VRSet 'SPIN_CTCACHE', 'Value', 16

    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window
return

/*:VRX         SW_DIRS_Close
*/
SW_DIRS_Close:
    call SW_DIRS_Fini
return

/*:VRX         SW_DIRS_Create
*/
SW_DIRS_Create:
    call SW_DIRS_Init
return

/*:VRX         SW_DIRS_Fini
*/
SW_DIRS_Fini:
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         SW_DIRS_Init
*/
SW_DIRS_Init:
    CALL VRSet 'EF_DIRRUN',  'Value', config.!torrentdir
    CALL VRSet 'EF_DIRSEED', 'Value', config.!seeddir
    CALL VRSet 'EF_DIRDEL',  'Value', config.!deldir
    CALL VRSet 'EF_DIRSAVE', 'Value', config.!downloaddir

    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window
return

/*:VRX         SW_PREFS_Close
*/
SW_PREFS_Close:
    call SW_PREFS_Fini
return

/*:VRX         SW_PREFS_Create
*/
SW_PREFS_Create:
    call SW_PREFS_Init
return

/*:VRX         SW_PREFS_Fini
*/
SW_PREFS_Fini:
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         SW_PREFS_Init
*/
SW_PREFS_Init:

    ok = VRMethod('Application', 'GetVar', 'DLSign', '_dl')
    IF ok == 0 THEN _dl = 'DL'
    ok = VRMethod('Application', 'GetVar', 'ULSign', '_ul')
    IF ok == 0 THEN _ul = 'UL'

    sorts.0 = 11
    sorts.1 = 'Name'
    sorts.2 = 'Size'
    sorts.3 = '% Done'
    sorts.4 = 'Seeders'
    sorts.5 = 'Leechers'
    sorts.6 = 'Speed' _dl
    sorts.7 = 'Speed' _ul
    sorts.8 = 'Total' _dl
    sorts.9 = 'Total' _ul
    sorts.10 = 'Ratio'
    sorts.11 = 'ETA'
    CALL VRMethod 'CMB_PREFSORT', 'AddStringList', 'sorts.'
    SELECT
        WHEN config.!sortcolumn == '!name'       THEN sortidx = 1
        WHEN config.!sortcolumn == '!z_kbytes'   THEN sortidx = 2
        WHEN config.!sortcolumn == '!z_percent'  THEN sortidx = 3
        WHEN config.!sortcolumn == '!z_seeders'  THEN sortidx = 4
        WHEN config.!sortcolumn == '!z_leechers' THEN sortidx = 5
        WHEN config.!sortcolumn == '!z_dlrate'   THEN sortidx = 6
        WHEN config.!sortcolumn == '!z_ulrate'   THEN sortidx = 7
        WHEN config.!sortcolumn == '!z_dloaded'  THEN sortidx = 8
        WHEN config.!sortcolumn == '!z_uloaded'  THEN sortidx = 9
        WHEN config.!sortcolumn == '!z_ratio'    THEN sortidx = 10
        WHEN config.!sortcolumn == '!z_eta'      THEN sortidx = 11
        OTHERWISE sortidx = 1
    END
    CALL VRSet 'CMB_PREFSORT', 'Selected', sortidx

    IF config.!sorttype == 'Descending' THEN
        CALL VRSet 'RB_PREFSORTD', 'Set', 1
    ELSE
        CALL VRSet 'RB_PREFSORTA', 'Set', 1

    starts.0 = 3
    starts.1 = 'Never'
    starts.2 = 'Single file only'
    starts.3 = 'Always'
    CALL VRMethod 'CMB_PREFSTART',  'AddStringList', 'starts.'
    CALL VRSet 'CMB_PREFSTART',  'Selected', config.!autostart
    CALL VRSet 'CHK_PREFDIALOG', 'Set',      config.!autodialog

    actions.0 = 3
    actions.1 = 'None'
    actions.2 = 'Stop local torrents'
    actions.3 = 'Stop all torrents'
    CALL VRMethod 'CMB_PREFONEXIT', 'AddStringList', 'actions.'

    CALL VRSet 'CMB_PREFONEXIT',   'Selected', config.!onexit
    CALL VRSet 'CHK_PREFCONFIRM',  'Set',      config.!confirmexit
    CALL VRSet 'CHK_PREFRESUME',   'Set',      config.!autoresume
    CALL VRSet 'SPIN_PREFINT',     'Value',    config.!interval % 1000
    CALL VRSet 'CHK_PREFSEEDCONF', 'Set',      config.!confirmseed
    CALL VRSet 'CHK_PREFDELORG',   'Set',      config.!deleteorg

    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window

RETURN

/*:VRX         SW_START_Close
*/
SW_START_Close:
    call SW_START_Fini
return

/*:VRX         SW_START_Create
*/
SW_START_Create:
    call SW_START_Init
return

/*:VRX         SW_START_Fini
*/
SW_START_Fini:
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         SW_START_Init
*/
SW_START_Init: PROCEDURE EXPOSE global. config. filefields. torrent old_savedir old_cmdline

    ct_name = TRANSLATE( VRParseFilePath( config.!ctorrent, 'N'))

    filefields.!number = VRMethod('CN_STFILES', 'AddField', ULong,  '#')
    filefields.!name   = VRMethod('CN_STFILES', 'AddField', String, 'File')
    filefields.!size   = VRMethod('CN_STFILES', 'AddField', String, 'Size')
/*
    CALL VRMethod 'CN_STFILES', 'SetFieldAttr', filefields.!number, 'VertSeparator',  0
    CALL VRMethod 'CN_STFILES', 'SetFieldAttr', filefields.!name,   'VertSeparator',  0
    CALL VRMethod 'CN_STFILES', 'SetFieldAttr', filefields.!size,   'VertSeparator',  0
*/
    CALL VRSet 'CN_STFILES', 'ShowTitles', 0

    CALL VRSet 'EF_STTORRENT', 'Value',    FILESPEC('NAME', torrent )
    CALL VRSet 'EF_STTORRENT', 'UserData', torrent
    IF old_savedir == '' THEN
        CALL VRSet 'EF_STSAVEDIR', 'Value', config.!downloaddir
    ELSE
        CALL VRSet 'EF_STSAVEDIR', 'Value', old_savedir

    /* Retrieve information about the torrent contents (trackers/files/etc).
     */
    CALL GetTorrentContents torrent

    /* Populate the tracker list.
     */
    CALL VRMethod 'CMB_STTRACKER', 'AddString', deftracker, 1, '0'
    CALL VRMethod 'CMB_STTRACKER', 'AddStringList', 'trackers.', 2, 'tracknos.'
    CALL VRSet 'CMB_STTRACKER', 'Selected', 1

    /* Parse any previously-configured file/tracker options for this torrent.
     */
    old_trackno = ''
    old_filenos = ''
    IF old_cmdline \= '' THEN DO
        PARSE UPPER VAR old_cmdline . ' -U ' old_trackno .
        IF ct_name == 'ACT' THEN
            PARSE UPPER VAR old_cmdline . ' -FILE ' old_filenos .
        ELSE
            PARSE UPPER VAR old_cmdline . ' -N ' old_filenos .
        IF global.!debug == 1 THEN DO
            CALL CHAROUT, 'Previous torrent options:'
            IF old_trackno \= '' THEN CALL CHAROUT, ' Tracker' old_trackno
            IF old_filenos \= '' THEN CALL CHAROUT, ', File(s)' old_filenos
            SAY
        END
    END

    IF old_trackno \= '' THEN
        CALL VRSet 'CMB_STTRACKER', 'Selected', old_trackno + 1
    ELSE IF ct_name \= 'CTORRENT9' THEN DO
        /* Search the torrent's trackers for one of our preferred trackers.
         */
        foundtracker = 0
        DO i = 1 TO global.!defaults.!trackers.0
            DO j = 1 TO trackers.0
                IF TRANSLATE( trackers.j ) == TRANSLATE( global.!defaults.!trackers.i ) THEN DO
                    foundtracker = j
                    LEAVE
                END
            END
            IF foundtracker > 0 THEN LEAVE
        END
        IF foundtracker > 0 THEN
            CALL VRSet 'CMB_STTRACKER', 'Selected', foundtracker + 1
    END

    /* Populate the files list.
     */
    IF directory \= '' THEN directory = directory'\'
    addfiles.0 = files.0
    DO i = 1 TO files.0
        _obpos = LASTPOS('[', files.i )
        _cbpos = LASTPOS(']', files.i )
        IF  ( _obpos > 0 & _cbpos > _obpos ) THEN DO
            filesize = SUBSTR( files.i, _obpos+1, _cbpos-_obpos-1 )
            filesize = Utils('ConvertBytes', filesize )
            filename = STRIP( SUBSTR( files.i, 1, _obpos-1 ))
        END
        addfiles.i = '*'filename'****'filefields.!number'*'filenos.i'*'filefields.!name'*'directory || filename'*'filefields.!size'*'filesize
    END
    CALL VRMethod 'CN_STFILES', 'AddRecordList',,, 'addfiles.', 'filerecs.'

    IF old_filenos \= '' THEN DO
        old_filenos = TRANSLATE( old_filenos, ' ', ',')
        DO i = 1 TO WORDS( old_filenos )
            _fno = WORD( old_filenos, i )
            IF SYMBOL('filerecs._fno') == 'VAR' THEN
                CALL VRMethod 'CN_STFILES', 'SetRecordAttr', filerecs._fno, 'Selected', 1
        END
    END
    ELSE
        CALL VRMethod 'CN_STFILES', 'SetRecordAttr', 'All', 'Selected', 1

    CALL VRSet 'DT_STSPACE', 'Caption', 'Total size:' totalsize

    /* Populate the command field.
     */
    CALL VRSet 'EF_STCOMMAND', 'Value', BuildTorrentCmd()

    /* Display the dialog.
     */
    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window

RETURN

/*:VRX         TM_REFRESH_Trigger
*/
TM_REFRESH_Trigger:
    CALL RefreshDisplay
RETURN

/*:VRX         UpdateMenuItems
*/
/* Updates the enabled state of menu items in the 'Selected' menu.  Called
 * whenever a record is selected in the torrents container.
 */
UpdateMenuItems: PROCEDURE EXPOSE global. config.
    ok = VRMethod('CN_TORRENTS', 'GetRecordList', 'Selected', 'records.')
    IF ok \= 1 THEN RETURN
    IF records.0 == 0 THEN DO
        /* No records selected, disable all items */
        is_active = 0
        CALL VRSet 'MI_STOP',     'Enabled', 0
        CALL VRSet 'MI_DELETE',   'Enabled', 0
        CALL VRSet 'MI_RESUME',   'Enabled', 0
        CALL VRSet 'MI_STARTOPT', 'Enabled', 0
    END
    ELSE IF records.0 == 1 THEN DO
        /* One item selected, enable/disable based on whether it's active */
        is_active = 0
        _urecord = VRMethod('CN_TORRENTS', 'GetRecordAttr', records.1, 'UserData')
        IF _urecord == '' THEN RETURN
        _client  = VRMethod('CN_UPDATE', 'GetFieldData', _urecord, global.!ufields.!x_socket )
        _icon    = VRMethod('CN_UPDATE', 'GetFieldData', _urecord, global.!ufields.!icon )
        IF _client > 0 | _icon <> '$4' THEN is_active = 1
        CALL VRSet 'MI_STOP',     'Enabled', is_active
        CALL VRSet 'MI_DELETE',   'Enabled', \is_active
        CALL VRSet 'MI_RESUME',   'Enabled', \is_active
        CALL VRSet 'MI_STARTOPT', 'Enabled', \is_active
    END
    ELSE DO
        /* For multiple selections, enable everything except start options */
        CALL VRSet 'MI_STOP',     'Enabled', 1
        CALL VRSet 'MI_DELETE',   'Enabled', 1
        CALL VRSet 'MI_RESUME',   'Enabled', 1
        CALL VRSet 'MI_STARTOPT', 'Enabled', 0
    END
RETURN

/*:VRX         ValidateDirectoryInput
*/
ValidateDirectoryInput: PROCEDURE
    PARSE ARG control

    input = STRIP( VRGet( control, 'Value'))
    IF input \= '' THEN input = VRExpandFileName( input )
    IF input == '' THEN
        CALL VRSet control, 'BackColor', 'Red'

RETURN input

/*:VRX         VerifyDirectory
*/
VerifyDirectory: PROCEDURE
    /* Make sure the specified directory exists; create it if necessary.
     */
    PARSE ARG filespec

    IF VRFileExists( filespec ) == 1 THEN
        RETURN VRIsDir( filespec )
    ELSE
        RETURN VRMkDir( filespec )

RETURN 0

/*:VRX         WN_MAIN_Close
*/
WN_MAIN_Close:
    call QuitWait
return

