#!/bin/bash
set -x
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Running as root!";
    exec "$0" "$@"
fi
#first check socat is installed in the system and install it


main (){

}
main "$@"