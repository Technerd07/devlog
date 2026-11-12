#!/bin/bash
#source "$(dirname "${BASH_SOURCE[0]}")/logs.sh"
source logs.sh
#set -x
SERVER_PORT=9090
DB_NAME="${DB_NAME:-devlog}"
DB_USER="${DB_USER:-devlog}"
DB_HOST="${DB_HOST:-devlog-svc}"
PG_PASSWORD="${PG_PASSWORD:-*123#}"
#psql only reads the password from PGPASSWORD, so map our variable to it
export PGPASSWORD="${PG_PASSWORD}"
export DB_HOST DB_USER DB_NAME PG_PASSWORD

#fixed: in ${s//%/..} a bare % means "end of string", so it must be escaped as \%
#fixed: backslashes are escaped first so printf '%b' doesn't treat them as escape codes
urldecode() { local s="${1//+/ }"; s="${s//\\/\\\\}"; printf '%b' "${s//\%/\\x}"; }
#case 1
push_to_psql (){
    local title="$1"
    local content="$2"
    #take title and content fields from capture_content () and then format accordingly and push to db 
    #fixed: stdout is the network socket, so debug text must go to stderr (>&2)
    echo "pushing to psql" >&2
    if [[ -z "${title}" || -z "${content}" ]]; then
        echo "Title and content are empty. Can't complete the push operation" >&2
        return 1
    fi
    #fixed: ON CONFLICT added so the same request creates a new note or updates an existing one (needs UNIQUE on notes.title)
    psql -X -q -v ON_ERROR_STOP=1 -w -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
     --set=note_title="$title" --set=note_content="$content" \
     >/dev/null <<< "INSERT INTO notes (title, content) VALUES (:'note_title', :'note_content') ON CONFLICT (title) DO UPDATE SET content = EXCLUDED.content;" || {
        append_logs "[DAEMON] ERROR: Failed to insert record into PostgreSQL." 
        return 1
    }
}
capture_content (){
    #first read the input received from curl
    read -r input_line || true
    #parse the input text to cut title and content received
    local content_length=0
   while read -r header; do
        [[ "$header" == $'\r' || -z "$header" ]] && break
        if [[ "$header" =~ ^Content-Length:\ ([0-9]+) ]]; then
            content_length="${BASH_REMATCH[1]}"
        fi
    done 
    # 3. Read the POST body data sent by curl
    local body=""
    #fixed: read -n / read -N can block forever waiting for bytes or a newline, head -c reads exactly N bytes
    #if (( content_length > 0 )); then
    #    read -n "$content_length" -r body || true
    #else
    #    read -r body || true
    #fi
    if (( content_length > 0 )); then
        body="$(head -c "$content_length")"
    else
        read -r -t 2 body || true
    fi

    # 4. Parse title and content from url-encoded body (e.g., title=foo&content=bar)
    local title=""
    local content=""
    
    #fixed: the old regex had the value in group 1 and the "&" in group 2, and + / %XX decoding was incomplete
    #if [[ "$body" =~ title=([^&]*)(&|$) ]]; then
    #    title="${BASH_REMATCH[1]}"
    #    title="${title//+/ }" # Basic space decode
    #fi
    #if [[ "$body" =~ content=([^&]*)(&|$) ]]; then
    #    content="${BASH_REMATCH[1]}"
    #    content="${content//+/ }"
    #fi
    if [[ "$body" =~ (^|&)title=([^&]*) ]]; then
        title="$(urldecode "${BASH_REMATCH[2]}")"
    fi
    if [[ "$body" =~ (^|&)content=([^&]*) ]]; then
        content="$(urldecode "${BASH_REMATCH[2]}")"
    fi

    echo "[DAEMON] Intercepted note creation -> Title: $title" >&2
    # 5. Insert into PostgreSQL container
       # 6. Send HTTP/1.1 response back to cli.sh through the socket stream
        #echo "Title of the Note: $safe_title"  >&2
    #echo -e "Content: $safe_content " >&2
    #call the psql db pushing function here 
    #TODO:
    if push_to_psql "$title" "$content";then
        printf 'HTTP/1.1 200 OK\r\n'
        printf 'Content-Type: text/plain\r\n'
        printf "Connection: close\r\n"
        printf "\r\n"
        printf "note created successfully \n"
        append_logs "SUCCESS" "Note created successfully" "Pushed Data to psql-server successfully"

        else 
            printf 'HTTP/1.1 500 Internal Server Error\r\n'
            printf 'Content-Type: text/plain\r\n'
            printf 'Connection: close\r\n'
            printf '\r\n'
            printf 'Failed to save note\n'
            append_logs "ERROR" "Failed to save note" "500 Internal server error! connection closed!"
    fi
}

#Export the functions to make them available for child process
#fixed: urldecode added (the child bash needs it too)
export -f capture_content push_to_psql append_logs urldecode
:<<'comment'
    case 2: updating the notes over local and remote 
    on the remote:
        first fetch the file id to the client and then after updating,
        delete the remote file and then push the file to the db accordingly
comment
listen (){
    echo "Listening on $SERVER_PORT (Press crtl+c to stop the server)"
   socat -v TCP-LISTEN:"${SERVER_PORT}",reuseaddr,fork SYSTEM:"bash -c capture_content"
}

main (){
    listen
}
main "$@"