#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/logs.sh"
set -x
SERVER_PORT=9090
DB_NAME="${DB_NAME:-devlog}"
DB_USER="${DB_USER:-devlog}"
DB_HOST="${DB_HOST:-devlog-db}"
#case 1
push_to_psql (){
    echo "TODO:"
    local title="$1"
    local content="$2"
    #take title and content fields from capture_content () and then format accordingly and push to db 
    echo "pushing to psql"
    if [[ -z "${title}" || -z "${content}" ]]; then
        echo "Title and content are empty. Can't complete the push operation"  
        return 1
    fi
    psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -c \
        "INSERT INTO notes (title, content) VALUES ('$title', '$content');" &>/dev/null || {
        echo "[DAEMON] ERROR: Failed to insert record into PostgreSQL." >&2
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
    if (( content_length > 0 )); then
        read -n "$content_length" -r body || true
    else
        read -r body || true
    fi

    # 4. Parse title and content from url-encoded body (e.g., title=foo&content=bar)
    local title=""
    local content=""
    
    if [[ "$body" =~ title=([^&]*)(&|$) ]]; then
        title="${BASH_REMATCH[1]}"
        title="${title//+/ }" # Basic space decode
    fi
    if [[ "$body" =~ content=([^&]*)(&|$) ]]; then
        content="${BASH_REMATCH[1]}"
        content="${content//+/ }"
    fi

    # Escape single quotes for SQL safety
    local safe_title="${title//\'/\'\'}"
    local safe_content="${content//\'/\'\'}"

    echo "[DAEMON] Intercepted note creation -> Title: $safe_title" >&2

    # 5. Insert into PostgreSQL container
    if [[ -n "$safe_title" ]] && [[ -n "$safe_content" ]]; then
        #TODO:
        echo "#psql function related stuff here"
    fi

    # 6. Send HTTP/1.1 response back to cli.sh through the socket stream
        #echo "Title of the Note: $safe_title"  >&2
    #echo -e "Content: $safe_content " >&2
    #call the psql db pushing function here 
    #TODO:
    if push_to_psql "${safe_title}" "${safe_content}";then
        printf  "HTTP/1.1 200 OK\r"
        printf "Content-Type: text/plain\r"
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
export -f capture_content push_to_psql append_logs
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