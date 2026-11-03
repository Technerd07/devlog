#!/bin/bash
set -euo pipefail

# Database connection variables with defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-devlog}"
DB_USER="${DB_USER:-postgres}"
DATA_DIR="${STORAGE_PATH:-/data/attachments}"
BACKUP_DIR="./backupdir"
newfile="${BACKUP_DIR}/${name}.txt"
#we will not be installing utilities on this cuz docker image build has all dependancies installed

func_ui (){
echo "=============devlog=============="
echo "Take,Update,Retreive,your notes your way :)"
echo "1: Write a new note"
echo "2: update the note selected"
echo "3: Retrevie all the notes selected"
}

Handle_notes (){ 
    #make anyoption locally save the file and then encrypt these files;
    #when pushing delete all files and save them to the db
    #first create a backupdir
    
    if [ -d "${BACKUP_DIR}" ]; then
        echo "Error dir does not exist"
        else
            mkdir -vp "${BACKUP_DIR}"
            return 0
    fi

    while true; do
     func_ui
     echo "enter options [1-3]: "
     read -r options
     case "${options}" in 
         1) 
          echo "Enter the Name Of the Note: "
          read -r name
            #create a new file on the name of the note and encrypt it after adding the contents 
          read -rp "Enter a New Note: " newnote
            if [[ -n "${newnote}" ]]; then 
                new_note="${new_note//\'/\'\'}"
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
                -c "INSERT INTO notes (content) VALUES ('$new_note');"
                printf '%s\n' "${newnote}" | tee -a  "${newfile}" >/dev/null
                #first push the complete note data and then encrypt the local file
                encrypt_localfiles
                else 
                echo "new note cant' be empty!"
            fi
         sleep 1
         ;; 
         2) 
         read -rp "Enter the note to update "
         #fetch the file name and then open that particular file from the db and then push it 
         #as the local file is stored inside the local machine the remote does also have the same content, just update the local files and push to remote
         #first list all the files that are stored and select one and update the notes

         sleep 1
         ;;
         3) read -rp "Retreive all the notes from the database " 

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

}

main (){
    Handle_notes
}
main "$@"