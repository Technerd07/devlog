#!/bin/bash

source  ./cli.sh

set -euo pipefail
main (){
    Handle_notes
}
main "$@"