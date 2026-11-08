#!/bin/bash
#set -euo pipefail

# Database connection variables with defaults
#DB_HOST="${DB_HOST:-localhost}"
#DB_PORT="${DB_PORT:-5432}"
#DB_NAME="${DB_NAME:-devlog}"
#DB_USER="${DB_USER:-postgres}"
#DATA_DIR="${STORAGE_PATH:-/data/attachments}"
BACKUP_DIR="/mnt/backupdir"
#backup directory name must match the volume mount unless it wont work 
BACKEND_URL="${BACKEND_URL:-http://localhost:9090}"
#we will not be installing utilities on this cuz docker image build has all dependancies installed

func_ui (){
echo "=============devlog=============="
echo "Take,Update,Retreive,your notes your way :)"
echo "1: Write a new note"
echo "2: update the note selected"
echo "3: Retrevie all the notes selected"
echo "4: EXIT"
}
send_note (){
    local title="$1";
    local content="$2" code ;
    code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "${BACKEND_URL}" \
            --data-urlencode "title=${title}" \
            --data-urlencode "content=${content}")" \
        || { echo "Server unreachable" >&2; return 1; }
    [[ "${code}" == 200 ]] || { echo "Server returned HTTP $code" >&2; return 1; }
}
Handle_notes (){ 
    #make anyoption locally save the file and then encrypt these files;
    #when pushing delete all files and save them to the db
    #first create a backupdir
    
    mkdir -p "${BACKUP_DIR}" || {
        echo "Unable to create backup directory: ${BACKUP_DIR}" >&2;
        return 1;
    }

    while true; do
     func_ui
     echo "enter options [1-4]: "
     read -r options
     case "${options}" in 
         1) 
         #New Note 
          read -rp "Enter the Name Of the Note: " name
          read -rp "Enter a New Note: " newnote
          name="${name//[^A-Za-z0-9._-]/_}"
          if [[ -z "${newnote}" ]] || [[ -z "${name}" ]]; then
             #changed the architecture to have client and server side 
             #client will be using curl for sending requests over backend to psql server
             echo "Name and note(text) can't be empty!"; continue
            fi
            echo "Sending note to server daemon....."
            send_note "$name" "$newnote" || echo "warning: not saved on the server " >&2 
            printf '%s\n' "${newnote}" > "${BACKUP_DIR}/${name}.txt"
            encrypt_localfiles "${BACKUP_DIR}/${name}.txt"
         sleep 1
         ;; 
         2) 
         #fetch the file name and then open that particular file from the db and then push it 
         #as the local file is stored inside the local machine the remote does also have the same content, just update the local files and push to remote
         #first list all the files that are stored and select one and update the notes
         #enter file name newfile
         #Update notes on the system  and push that to db
         read -rp "Enter the filename (note) to update " notename 
         notename="${notename//[^A-Za-z0-9._-]/_}"
            #check wether the note name is empty 
            [[ -z "${notename}" ]] && { echo "Note name can't be empty "; continue; }
                #check wether the entered name of the file exists on the backupdir
                agefile="${BACKUP_DIR}/${notename}"
                if [ ! -f "${agefile}.txt.age" ]; then
                    echo "File doesnot exist on the path "
                    continue;
                fi
                    decryptedfile=$(decrypt_localfiles "${agefile}") || continue;
                    original_content=$(cat "${decryptedfile}")
                    #Using 'vi' instead of 'vim' in the alpine container builds work 
                    "${EDITOR:-vi}" "${decryptedfile}" ||  { rm -f "${decryptedfile}" ; contunue ;} 
                    #re-encrypt after editing files
                    content="$(cat "${decryptedfile}")"
                    if [[ "${content}" -eq "${original_content}" ]]; then
                        rm -f "${decryptedfile}"
                        echo "No changes have been applied to file"
                        continue;
                    fi
                    encrypt_local_fiiles "${decryptedfile}"
                    echo "Local: ${notename} re-encrypted successfully"
                    #scheduled note push to server using background jobs
                    (sleep 120 ; send_note "${notename}" "${content}") &
                    sleep 1
                ;;
         3) read -rp "Retreive all the notes from the database " 
         #working on it...
         #list all the files from the backupdir
         if [[ -d "${BACKUP_DIR}" ]]; then
            find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.txt.age' -print | awk -F '/' '{print $NF}' | sed 's/\.txt\.age$//'
            else
             echo "Directory doesnot exist"
         fi
         sleep 1
         ;;
        4)
        echo "waiting for pending updates"
        wait
         printf '%s\n' "Goodbye :)"
         break
          ;;
        *) 
        echo "choose [1-4]" ;;
    esac
    sleep 1
  done
}
encrypt_localfiles (){ 
    #Usng age cmdline utility file encryption
    #first generate a private key to a file
    local targetfile="$1"
    local privatekeyfile="${HOME}/.config/age/devlog-identity.txt"
    local recipient

    mkdir -p "$(dirname "$privatekeyfile")"

    if [[ ! -f "$privatekeyfile" ]]; then
        age-keygen -o "$privatekeyfile"
        chmod 600 "$privatekeyfile"
    fi

    #store the encryption public key into the variable and use that to encrypt the file
    recipient="$(age-keygen -y "$privatekeyfile")"

    if [[ ! -f "${targetfile}" ]]; then
        printf 'Backup file not found : %s\n' "${targetfile}"
        return 1
    fi
    #encrypt the file using age
    age -r "${recipient}" -o "${targetfile}.age" "${targetfile}" && rm -f "${targetfile}"
    echo "Ecrypting Notes Completed Successfully"
}
decrypt_localfiles (){
    local privatekeyfile="${HOME}/.config/age/devlog-identity.txt"
    local encryptedfile=$1  #notename
    local plaintextfile="${encryptedfile}.txt"
    #add the decryption logic for decrypting the files
    if [[ ! -f "${encryptedfile}.txt.age" ]]; then
        printf 'Encrypted note not found: %s\n' "${encryptedfile}" >&2
        return 1
    fi
    age --decrypt \
    --identity "${privatekeyfile}" \
    --output "${plaintextfile}" \
    "${encryptedfile}.txt.age" || return 1

    echo "${plaintextfile}"
}