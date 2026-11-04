#!/bin/bash
#set -euo pipefail

# Database connection variables with defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-devlog}"
DB_USER="${DB_USER:-postgres}"
DATA_DIR="${STORAGE_PATH:-/data/attachments}"
BACKUP_DIR="/home/backupdir"
newfile="${BACKUP_DIR}/${name}.txt"
#we will not be installing utilities on this cuz docker image build has all dependancies installed

func_ui (){
echo "=============devlog=============="
echo "Take,Update,Retreive,your notes your way :)"
echo "1: Write a new note"
echo "2: update the note selected"
echo "3: Retrevie all the notes selected"
echo "4: EXIT"
}

Handle_notes (){ 
    #make anyoption locally save the file and then encrypt these files;
    #when pushing delete all files and save them to the db
    #first create a backupdir
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        echo "Error dir does not exist"
        else
            mkdir -vp "${BACKUP_DIR}"
            return 0
    fi

    while true; do
     func_ui
     echo "enter options [1-4]: "
     read -r options
     case "${options}" in 
         1) 
         #New Note 
          read -rp "Enter the Name Of the Note: " name
          read -rp "Enter a New Note: " newnote
          if [[ -n "${newnote}" ]] && [[ -n "${name}" ]]; then
          # Escape single quotes for safety
          safe_name="${name//\'/\'\'}"
          safe_note="${newnote//\'/\'\'}"

         # Insert both title and content into PostgreSQL
         PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
         -c "INSERT INTO notes (title, content) VALUES ('$safe_name', '$safe_note');"
              # Local file creation
              newfile="${BACKUP_DIR}/${name}.txt"
              printf '%s\n' "${newnote}" > "${newfile}"
              #first push the complete note data and then encrypt the local file
              encrypt_localfiles
            else 
                echo "new note cant' be empty!"
            fi
         sleep 1
         ;; 
         2) 
         #fetch the file name and then open that particular file from the db and then push it 
         #as the local file is stored inside the local machine the remote does also have the same content, just update the local files and push to remote
         #first list all the files that are stored and select one and update the notes
         #enter file name newfile
         #Update notes on the system  and push that to db
         read -rp "Enter the filename (note) to update " notename 
            if [ -n "${notename}" ];then
                #check wether the entered name of the file exists on the backupdir
                agefile="${BACKUP_DIR}/${notename}"
                if [ ! -f "${agefile}.txt.age" ]; then
                    echo "File doesnot exist on the path "
                  else
                    #1 first using the notename retreive the noteid from the database
                    note_id=$(PGPASSWORD="$DB_PASSWORD" psql \
                     -h "$DB_HOST" -p "$DB_PORT" \
                     -U "$DB_USER" -d "$DB_NAME" \
                     -t -A \
                     -v title_val="${notename}" \
                     -c "SELECT id FROM notes WHERE title = :'title_val' LIMIT 1;")
                     #next store the note id 
                     note_id=$(echo "${note_id}" | xargs)
                     #check wether the note is present on that particular noteid on the database
                     if [[ -z "${note_id}" ]]; then
                        echo "Error: no matching note found in the databae for title: '${notename}'. "
                        else
                        echo "Found Note ID: ${note_id} . Opening for edit...."
                        sleep 1
                        decryptedfile=$(decrypt_localfiles "${agefile}" || return 1)
                       "${EDITOR:-vim}" "${decryptedfile}" || return 1
                        #push-db-logic here...
                    # Read the updated content from the decrypted text file and escape single quotes
                 updated_content=$(cat "${BACKUP_DIR}/${notename}.txt")
                 updated_content="${updated_content//\'/\'\'}"
                 
                 # Push the update to PostgreSQL using the note_id
                 PGPASSWORD="$DB_PASSWORD" psql \
                     -v ON_ERROR_STOP=1 \
                     -h "$DB_HOST" -p "$DB_PORT" \
                     -U "$DB_USER" -d "$DB_NAME" \
                     -c "UPDATE notes SET content = '${updated_content}' WHERE id = ${note_id};"
                     fi
                  fi
                else 
                echo "Note name cant be null, Please enter Note Name correctly"
                return 1
            fi
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
         printf '%s\n' "Goodbye :)"
         break
          ;;
    esac
  done
}
encrypt_localfiles (){ 
    #Usng age cmdline utility file encryption
    #first generate a private key to a file
    local privatekeyfile="${HOME}/.config/age/devlog-identity.txt"
    local recipient

    mkdir -p "$(dirname "$privatekeyfile")"

    if [[ ! -f "$privatekeyfile" ]]; then
        age-keygen -o "$privatekeyfile"
        chmod 600 "$privatekeyfile"
    fi

    #store the encryption public key into the variable and use that to encrypt the file
    recipient="$(age-keygen -y -i "$privatekeyfile")"

    if [[ ! -f "${newfile}" ]]; then
        printf 'Backup file not found : %s\n' "${newfile}"
        return 1
    fi
    #encrypt the file using age
    age -r "${recipient}" -o "${newfile}.age" "${newfile}"
}
decrypt_localfiles (){
    local privatekeyfile="${HOME}/.config/age/devlog-identity.txt"
    local filename=$1  #notename
    local encryptedfile="${BACKUP_DIR}/${notename}.txt.age"
    local plaintextfile="${BACKUP_DIR}/${notename}.txt"
    #add the decryption logic for decrypting the files
    if [[ -f "${encryptedfile}" ]]; then
        printf 'Encrypted note not found: %s\n' "${encryptedfile}" >&2
    fi
    age --decrypt \
    --identity "${privatekeyfile}" \
    --output "${plaintextfile}" \
    "${encryptedfile}"
}

main (){
    Handle_notes
}
main "$@"