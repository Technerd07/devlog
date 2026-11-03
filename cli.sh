#!/bin/bash
set -euo pipefail

# Database connection variables with defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-devlog}"
DB_USER="${DB_USER:-postgres}"
DATA_DIR="${STORAGE_PATH:-/data/attachments}"
newfile=$(touch -a "${backupdir}/${name}".txt)

func_ui (){
echo "=============dev-vlog=============="
echo "Take,Update,Retreive,your notes your way :)"
echo "1: Write a new note"
echo "2: update the note selected"
echo "3: Retrevie all the notes selected"
}

Handle_notes (){ 
    #make anyoption locally save the file and then encrypt these files;
    #when pushing delete all files and save them to the db
    #first create a backupdir
    
    if [ -d "${backupdir}" ]; then
        echo "Error dir does not exist"
        else
            mkdir -vp "${backupdir}"
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
                 tee "${newnote}" >> "${newfile}"
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


         sleep 1
         ;;
         3) read -rp "Retreive all the notes from the database " 

        esac
  done
}
encrypt_localfiles (){

}