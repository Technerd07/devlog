#!/bin/bash
set -x
SERVER_PORT=9090
DB_NAME="${DB_NAME:-devlog}"
DB_USER="${DB_USER:-postgres}"
#case 1
capture_content (){

}
listen (){
    echo "Listening on $SERVER_PORT (Press crtl+c to stop the server)"
   socat -v TCP-LISTEN:"${SERVER_PORT}",reuseaddr,fork SYSTEM:"echo -e 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello from server :)'"
}
main (){
    listen
}
main "$@"