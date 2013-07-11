/*:VRX         Main
*/
Main:
    signal on halt

    PARSE ARG socket
    IF socket == '' | socket < 1 THEN EXIT

    finished = 0
    CALL VRInit
    DO WHILE finished == 0
        csock = SockAccept( socket )
        IF csock > 0 THEN DO
            CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Event_Incoming', 'ClientSocket', csock
        END
        _VREEvent = VREvent('N')
        INTERPRET _VREEvent
    END
    IF socket > 0 THEN DO
        rc = SockShutdown( socket, 2 )
        IF rc \= 0 THEN SAY 'SockShutdown() returned' rc
        rc = SockClose( socket )
        IF rc \= 0 THEN SAY 'SockClose() returned' rc
    END
    CALL VRFini

EXIT

/*:VRX         Halt
*/
Halt:
    IF socket > 0 THEN rc = SockClose( socket )
    CALL VRMethod 'Application', 'PostQueue', 0, 1, 'CALL Quit'
    CALL VRFini
EXIT

