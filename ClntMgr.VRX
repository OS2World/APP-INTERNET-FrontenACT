/*:VRX         Main
*/
Main:
    SIGNAL ON HALT
    NUMERIC DIGITS 11

    PARSE ARG _debug
    flags.!debug = _debug
    DROP _debug

    connections.0 = 0
    finished = 0
    quit_pending = 0
    quit_torrents.0 = 0

    CALL VRInit
    DO WHILE finished == 0
        restart_loop = 0
        DO i = 1 TO connections.0
            socket = connections.i

            /* Initialize these per-connection variables if they haven't already been defined. */
            IF SYMBOL('torrents.socket.!buffer')    == 'LIT' THEN torrents.socket.!buffer = ''
            IF SYMBOL('torrents.socket.!statusint') == 'LIT' THEN torrents.socket.!statusint = 0
            IF SYMBOL('torrents.socket.!silentint') == 'LIT' THEN torrents.socket.!silentint = 0

            rc = SockRecv( socket, 'data', 1000 )
            IF rc < 0 THEN DO
                IF errno == 'EWOULDBLOCK' THEN NOP
                ELSE DO
                    CALL DeleteConnection socket
                    restart_loop = 1
                    LEAVE
                END
            END
            ELSE IF rc == 0 THEN DO
                CALL DeleteConnection socket
                restart_loop = 1
                LEAVE
            END
            ELSE DO
                torrents.socket.!silentint = 0
                nlpos = POS('0a'x, data )
                DO WHILE nlpos > 0
                    PARSE VAR data _text '0a'x data
                    torrents.socket.!buffer = torrents.socket.!buffer || _text
                    CALL ProcessCommand socket torrents.socket.!buffer
                    torrents.socket.!buffer = ''
                    nlpos = POS('0a'x, data )
                END
                torrents.socket.!buffer = torrents.socket.!buffer || data
            END

            /* Periodically request a full status update */
            torrents.socket.!statusint = torrents.socket.!statusint + 1
            IF torrents.socket.!statusint > 2 THEN DO
                CALL SEND_SENDSTATUS socket
                torrents.socket.!statusint = 0
            END

            /* Mark torrets that have been silent for too long (~60 secs) */
            IF torrents.socket.!silentint < 20 THEN
                torrents.socket.!silentint = torrents.socket.!silentint + 1
            IF torrents.socket.!silentint == 20 THEN
                CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_CTDead' socket

        END

        DO UNTIL _VREEvent == 'nop'
            _VREEvent = VREvent('N')
            INTERPRET _VREEvent
        END

        IF finished == 0 & restart_loop == 0 THEN 
            CALL SysSleep 3
    END

    /* Close all sockets.
     */
    DO i = 1 TO connections.0
        CALL SockClose connections.i
    END

    /* Tell the main program to shut down.
     */
    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Quit'
    CALL VRFini
EXIT

/*:VRX         AddConnection
*/
AddConnection: PROCEDURE EXPOSE connections. torrents.
    PARSE ARG new_socket

    IF new_socket > 0 THEN DO
        _count = connections.0 + 1
        connections._count = new_socket
        connections.0 = _count

        torrents.new_socket.!proto_ver = 1
        /* CALL InitTorrent new_socket */
    END

RETURN 0

/*:VRX         CTCS_CTBW
*/
CTCS_CTBW: PROCEDURE EXPOSE torrents.
    PARSE ARG client dl_rate ',' ul_rate dl_limit ',' ul_limit

    /* This message is a 'mini-update' that only refreshes the UL/DL rate.
     */
    torrents.client.!dl_rate = dl_rate
    torrents.client.!ul_rate = ul_rate

    /* Signal the main program window to update the torrent overview display.
     */
    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_CTUpdateShort' client,,
                  'CTData', dl_rate ul_rate

RETURN 0

/*:VRX         CTCS_CTDETAIL
*/
CTCS_CTDETAIL: 
    PARSE ARG client torrent_size piece_size current_timestamp seed_timestamp

    torrent.!size         = torrent_size 
    torrent.!piece_size   = piece_size
    torrent.!current_time = current_timestamp
    torrent.!seed_time    = seed_timestamp

    ctdata = torrent_size piece_size current_timestamp seed_timestamp
    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_CTDetail' client,,
                  'CTData', ctdata

RETURN 0

/*:VRX         CTCS_CTORRENT
*/
CTCS_CTORRENT: 
    PARSE ARG client peer_id start_timestamp current_timestamp filename 

    torrents.client.!peer_id      = peer_id
    torrents.client.!start_time   = start_timestamp
    torrents.client.!current_time = current_timestamp
    torrents.client.!filename     = filename

    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_CTorrent' client,,
                  'CTPeerID', peer_id, 'CTFileName', filename

RETURN 0

/*:VRX         CTCS_CTSTATUS
*/
CTCS_CTSTATUS:
    PARSE ARG client parameters

    IF SYMBOL('torrents.client.!proto_ver') == 'LIT' THEN torrents.client.!proto_ver = 1

    IF torrents.client.!proto_ver > 1 THEN DO
        PARSE VAR parameters seeders ':' tseeders '/' leechers ':' tleechers '/' cnct have '/' total '/' avail dlrate ',' ulrate dltotal ',' ultotal dllimit ',' ullimit cache 
    END
    ELSE DO
        PARSE VAR parameters seeders'/'leechers have'/'total'/'avail dlrate','ulrate dltotal','ultotal dllimit ',' ullimit 
        tseeders  = '?'
        tleechers = '?'
        cnct      = '?'
        cache     = '?'        
    END
/*
    torrents.client.!seeders      = seeders
    torrents.client.!tot_seeders  = tseeders
    torrents.client.!leechers     = leechers
    torrents.client.!tot_leechers = tleechers
    torrents.client.!connections  = cnct
    torrents.client.!num_have     = have
    torrents.client.!num_total    = total
    torrents.client.!num_avail    = avail
    torrents.client.!cache        = cache
    torrents.client.!dl_rate      = dlrate
    torrents.client.!ul_rate      = ulrate
    torrents.client.!dl_total     = dltotal
    torrents.client.!ul_total     = ultotal
    torrents.client.!dl_limit     = dllimit
    torrents.client.!ul_limit     = ullimit
*/
    /* Signal the main program window to update the torrent overview display.
     */
    ctdata = seeders tseeders leechers tleechers cnct have total avail dlrate ulrate dltotal ultotal
    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_CTUpdateLong' client, 'CTData', ctdata

RETURN 0

/*:VRX         CTCS_PROTOCOL
*/
CTCS_PROTOCOL: 
    PARSE ARG client protocol

    /* Set the CTCS protocol version reported by this client.
     */
    torrents.client.!proto_ver = STRIP( protocol, 'L', '0')
    IF torrents.client.!proto_ver > 3 THEN torrents.client.!proto_ver = 3

    /* Now report our own version back to the client.
     */
    rc = SockSend( client, 'PROTOCOL 0003' || '0A'x )

RETURN 0

/*:VRX         DeleteConnection
*/
DeleteConnection: 
    PARSE ARG close_socket

    /* Remove from the list of active torrents. 
     */
    found = 0
    DO i = 1 TO connections.0
        IF connections.i == close_socket THEN DO
            found = i
            LEAVE
        END
    END
    ok = 1
    IF found > 0 THEN DO
        ok = SysStemDelete('connections.', found, 1 )
        DROP torrents.found.
    END

    /* Remove from the list of quit-pending torrents.
     */
    found = 0
    DO i = 1 TO quit_torrents.0
        IF quit_torrents.i == close_socket THEN DO
            found = i
            LEAVE
        END
    END
    IF found > 0 THEN DO
        CALL SysStemDelete 'quit_torrents.', found, 1 
        IF flags.!debug == 1 THEN 
            SAY 'Client on socket' close_socket 'has closed ('quit_torrents.0 'still to close)'
    END

    CALL SockClose close_socket

    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_Disconnect' close_socket

    IF ( quit_pending > 0 ) & ( quit_torrents.0 == 0 ) THEN 
        finished = 1

RETURN ok

/*:VRX         Event_Close
*/
Event_Close: PROCEDURE EXPOSE connections.

    PARSE ARG socket
    rc = DeleteConnection( socket )

RETURN

/*:VRX         Event_New
*/
Event_New: PROCEDURE EXPOSE connections.

    PARSE ARG socket 
    rc = AddConnection( socket )

RETURN

/*:VRX         Event_SendCommand
*/
Event_SendCommand: 

    /* Signalled by the UI thread when a command must be sent to the CTorrent
     * according to something that was determined in the main window (e.g. a
     * user selection).
     */
    PARSE ARG _client _command

    IF flags.!debug == 1 THEN SAY 'Sending ('_client')' _command 

    SELECT
        WHEN _command == 'CTQUIT'     THEN CALL SEND_CTQUIT     _client
        WHEN _command == 'CTRESTART'  THEN CALL SEND_CTRESTART  _client
        WHEN _command == 'CTUPDATE'   THEN CALL SEND_CTUPDATE   _client
        WHEN _command == 'SENDCONF'   THEN CALL SEND_SENDCONF   _client
        WHEN _command == 'SENDDETAIL' THEN CALL SEND_SENDDETAIL _client
        WHEN _command == 'SENDSTATUS' THEN CALL SEND_SENDSTATUS _client
        WHEN _command == 'SENDPEERS'  THEN CALL SEND_SENDPEERS  _client
        OTHERWISE NOP
    END

    DROP _client
    DROP _command

RETURN 0

/*:VRX         Halt
*/
Halt:
    /* Close all sockets.
     */
    DO i = 1 TO connections.0
        CALL SockClose connections.i
    END

    /* If the connection manager died, we'd better terminate the program.
     */
    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Quit'
    CALL VRFini
EXIT

/*:VRX         InitTorrent
*/
InitTorrent: 
    PARSE ARG id

    torrents.id.!proto_ver    = 1

    torrents.id.!peer_id      = '?'
    torrents.id.!start_time   = '?'
    torrents.id.!current_time = '?'
    torrents.id.!filename     = '?'
    torrents.id.!seeders      = '?'
    torrents.id.!tot_seeders  = '?'
    torrents.id.!leechers     = '?'
    torrents.id.!tot_leechers = '?'
    torrents.id.!connections  = '?'
    torrents.id.!num_have     = '?'
    torrents.id.!num_total    = '?'
    torrents.id.!num_avail    = '?'
    torrents.id.!dl_rate      = '?'
    torrents.id.!ul_rate      = '?'
    torrents.id.!dl_total     = '?'
    torrents.id.!ul_total     = '?'
    torrents.id.!ul_limit     = '?'
    torrents.id.!dl_limit     = '?'
    torrents.id.!cache        = '?'
    torrents.id.!size         = '?'
    torrents.id.!piece_size   = '?'
    torrents.id.!seed_time    = '?'

    /* For some reason this isn't persistent when the function returns... ?!!? */
    torrents.id.!buffer       = ''

RETURN 0

/*:VRX         ProcessCommand
*/
ProcessCommand: 
/* PROCEDURE EXPOSE connections. torrents. */
    PARSE ARG client command parameters

/*  IF flags.!debug == 1 THEN SAY 'Sending ('_client')' command  */

    SELECT
        WHEN command == 'PROTOCOL'      THEN CALL CTCS_PROTOCOL client parameters
        WHEN command == 'CTORRENT'      THEN CALL CTCS_CTORRENT client parameters
        WHEN command == 'CTSTATUS'      THEN CALL CTCS_CTSTATUS client parameters
        WHEN command == 'CTBW'          THEN CALL CTCS_CTBW     client parameters
        WHEN command == 'CTDETAIL'      THEN CALL CTCS_CTDETAIL client parameters
/*
        WHEN command == 'AUTH'          THEN CALL CTCS_AUTH parameters
        WHEN command == 'CTCONFIG'      THEN CALL CTCS_CTCONFIG parameters
        WHEN command == 'CTCONFIGDONE'  THEN CALL CTCS_CTCONFIGDONE parameters
        WHEN command == 'CTCONFIGSTART' THEN CALL CTCS_CTCONFIGSTART parameters
        WHEN command == 'CTFILE'        THEN CALL CTCS_CTFILE parameters
        WHEN command == 'CTFILESDONE'   THEN CALL CTCS_CTFILESDONE parameters
        WHEN command == 'CTFILESTART'   THEN CALL CTCS_CTFILESTART parameters
        WHEN command == 'CTINFO'        THEN CALL CTCS_CTINFO parameters
        WHEN command == 'CTPEER'        THEN CALL CTCS_CTPEER parameters
        WHEN command == 'CTPEERSDONE'   THEN CALL CTCS_CTPEERSDONE parameters
        WHEN command == 'CTPEERSTART'   THEN CALL CTCS_CTPEERSTART parameters
        WHEN command == 'CTFDONE'       THEN CALL CTCS_CTFILESDONE parameters
        WHEN command == 'CTFILES'       THEN CALL CTCS_CTFILESTART parameters
        WHEN command == 'CTPDONE'       THEN CALL CTCS_CTPEERSDONE parameters
        WHEN command == 'CTPEERS'       THEN CALL CTCS_CTPEERSTART parameters
        WHEN command == 'X-RUNNING'     THEN CALL CTCS_X-RUNNING parameters
*/
        OTHERWISE NOP
    END

RETURN 0

/*:VRX         SEND_CTQUIT
*/
SEND_CTQUIT: PROCEDURE
    PARSE ARG socket
    rc = SockSend( socket, 'CTQUIT' || '0A'x ) 
RETURN rc

/*:VRX         SEND_CTRESTART
*/
SEND_CTRESTART: PROCEDURE
    PARSE ARG socket
    rc = SockSend( socket, 'CTRESTART' || '0A'x )
RETURN rc

/*:VRX         SEND_CTUPDATE
*/
SEND_CTUPDATE: PROCEDURE
    PARSE ARG socket
    rc = SockSend( socket, 'CTUPDATE' || '0A'x )
RETURN rc

/*:VRX         SEND_SENDCONF
*/
SEND_SENDCONF: PROCEDURE
    PARSE ARG socket
    rc = SockSend( socket, 'SENDCONF' || '0A'x )
RETURN rc

/*:VRX         SEND_SENDDETAIL
*/
SEND_SENDDETAIL: PROCEDURE 
    PARSE ARG socket
    rc = SockSend( socket, 'SENDDETAIL' || '0A'x )
RETURN rc

/*:VRX         SEND_SENDPEERS
*/
SEND_SENDPEERS: PROCEDURE
    PARSE ARG socket
    rc = SockSend( socket, 'SENDPEERS' || '0A'x )
RETURN rc

/*:VRX         SEND_SENDSTATUS
*/
SEND_SENDSTATUS: PROCEDURE
    PARSE ARG socket
    rc = SockSend( socket, 'SENDSTATUS' || '0A'x )
RETURN rc

/*:VRX         Shutdown
*/
Shutdown: 
    ARG _option

    quit_torrents.0 = 0
    IF ( _option > 1 ) & ( connections.0 > 0 ) THEN DO
        quit_pending = 0
        DO i = 1 TO connections.0
            rc = SockGetPeerName( connections.i, 'address.!')
            IF rc \= 0 THEN ITERATE
            IF option == 3 | address.!addr == '127.0.0.1' | address.!addr == 'localhost' THEN DO
                CALL SEND_CTQUIT connections.i
                quit_pending = quit_pending + 1
                quit_torrents.quit_pending = connections.i
            END
        END
        quit_torrents.0 = quit_pending
        IF flags.!debug == 1 THEN SAY 'Waiting for' quit_pending 'clients to close.'
    END

    IF quit_torrents.0 == 0 THEN
        finished = 1

RETURN

