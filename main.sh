#!/bin/bash

source  ./cli.sh
source ./backend.sh

set -euo pipefail
main (){
    func_ui
}
main "$@"