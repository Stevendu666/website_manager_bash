
#!/bin/bash

# Set variables
INTRANET_DIR="/var/www/html/intranet"
LIVE_DIR="/var/www/html/live"
BACKUP_DIR="/var/www/html/backups"
LOG_FILE="/var/log/site.log"
AUDIT_DIR="/var/www/audit"
USERNAME="$(whoami)"
NOW="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_TIME="02:00" # Specify backup time here (24-hour format)

# Function to backup Intranet Directory
function backup_intranet {
  echo "Backing up Intranet Directory..."
  
  # Create backup directory if it doesn't exist
  if [ ! -d "$BACKUP_DIR/$NOW/intranet" ]; then
    sudo mkdir -p "$BACKUP_DIR/$NOW/intranet"
  fi
  
  # Check if the backup directory was created successfully
  if [ ! -d "$BACKUP_DIR/$NOW/intranet" ]; then
    echo "Error: Failed to create backup directory."
    return 1
  fi
  # Temporarily restrict other users from modifying the Intranet directory
  sudo chmod -R o-w "$INTRANET_DIR"
  
  # Backup and compress the Intranet directory
  sudo chown $USERNAME:$USERNAME "$INTRANET_DIR"
  sudo cp -r /var/www/html/live /var/www/html/intranet
  sudo tar -czf "$BACKUP_DIR/$NOW/intranet/Intranet-archive-$(date +%Y-%m-%d).zip" "$INTRANET_DIR/"

  # Restore permissions to the Intranet directory
  sudo chmod -R o+w "$INTRANET_DIR"

  echo "Backup completed."
}

# Function to backup Live Directory
function backup_live {
  echo "Backing up Live Directory..."
  
  # Create backup directory if it doesn't exist
  if [ ! -d "$BACKUP_DIR/$NOW/live" ]; then
    sudo mkdir -p "$BACKUP_DIR/$NOW/live"
  fi
  
  # Check if the backup directory was created successfully
  if [ ! -d "$BACKUP_DIR/$NOW/live" ]; then
    echo "Error: Failed to create backup directory."
    return 1
  fi
  
  # Backup and compress the Live directory
  sudo chown $USERNAME:$USERNAME "$LIVE_DIR"
  sudo tar -czf "$BACKUP_DIR/$NOW/live/Live-archive-$(date +%Y-%m-%d).zip" "$LIVE_DIR/"

  # Restrict live directory permissions,only read
  sudo chmod -R 555 "$LIVE_DIR"
  
  echo "Backup completed."
}

# Function to transfer updates to Live Directory
function transfer_updates() {
   
  # Function to compare Intranet and Live directories for changes
  function compare_directories() {
    # Create a temporary file to store the diff output
    tmp_file=$(mktemp)

    # Compare the Intranet and Live directories and output the result to the temporary file
    diff -r $INTRANET_DIR $LIVE_DIR > $tmp_file

    # Check if the temporary file is empty (i.e. no differences found)
    if [[ ! -s $tmp_file ]]; then
      echo "No changes detected."
    else
      # Log the changes to the site.log file
      echo "$(date) - User $USERNAME made the following changes to the Intranet directory:" >> $LOG_FILE
      echo "$(date) - $USERNAME $tmp_file" >> $LOG_FILE
      cat $USERNAME $tmp_file >> $LOG_FILE

      # Sync the changes to the Live directory
      sudo rsync -av --delete $INTRANET_DIR/ $LIVE_DIR/

      echo "Changes synced to Live directory."
    fi

    # Remove the temporary file
    rm $tmp_file
  }

  # Compare directories for changes
  compare_directories
}


# Function to generate audit report


function audit_report {
  echo "Generating audit report..."
   # Create directory if it doesn't exist
  if [ ! -d "$AUDIT_DIR/$NOW" ]; then
    sudo mkdir -p "$AUDIT_DIR/$NOW"
  fi

  if [ ! -f "$AUDIT_DIR/$NOW/audit-report-$(date +%Y-%m-%d).txt" ]; then
    sudo touch "$AUDIT_DIR/$NOW/audit-report-$(date +%Y-%m-%d).txt"
  fi
  sudo chown -R $USERNAME:$USERNAME $AUDIT_DIR
  sudo chmod -R u+w $AUDIT_DIR
  
  sudo grep "$USERNAME" "$LOG_FILE" > "$AUDIT_DIR/$NOW/audit-report-$(date +%Y-%m-%d).txt"
  sudo cat "$LOG_FILE" >> "$AUDIT_DIR/$NOW/audit-report-$(date +%Y-%m-%d).txt"

  echo "Audit report generated."
  echo "File location: $AUDIT_DIR/$NOW/audit-report-$(date +%Y-%m-%d).txt"
}


# Function to check system health
function system_health {
  echo "Checking system health..."
  df -h
  echo
  top -n 1 -b
  echo
}

# Function to monitor Intranet directory for changes
function monitor_intranet {
  echo "Monitoring Intranet Directory for changes..."
  inotifywait -m -e modify,create,delete -r "$INTRANET_DIR" --exclude '^\..*' |
  while read path action file; do
    echo "Detected change in $path$file: $action"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - User $USERNAME $action file '$file' on $path" >> "$LOG_FILE"
  done
}


while true; do
    clear
    echo "=== Website Manager ==="
    echo "1. List Users"
    echo "2. Add user to web group"
    echo "3. Backup Intranet Directory"
    echo "4. Backup Live Directory"
    echo "5. Transfer Updates to Website"
    echo "6. Audit Reports"
    echo "7. System Health Reports"
    echo "q. Quit"
    echo ""
    read -p "Enter your choice: " choice
    sudo chown -R $USERNAME:$USERNAME /var/www/html
    case $choice in
        1) 
            echo "=== List Users ==="
            echo "Listing users... "
            cat /etc/passwd | cut -d: -f1 | sort
            echo "***********************************"
            echo "Currently user is $USERNAME"
            read -p "Press enter to continue"
            ;;
        2) 
            echo "=== Add user to web group ==="
            read -p "Enter username to add: " username
            echo "Adding user $username to web group..."
            sudo usermod -a -G www-web "$username"
            read -p "Press enter to continue"
            ;;
        3) 
            echo "=== Backup Intranet Directory ==="
            echo "Backing up Intranet directory..."
            backup_intranet
            read -p "Press enter to continue"
            ;;
        4) 
            echo "=== Backup Live Directory ==="
            echo "Backing up Live directory ..."
            backup_live
            read -p "Press enter to continue"
            ;;
        5) 
            echo "=== Transfer Updates to Website ==="
            echo "Transferring updates to website..."
            transfer_updates
            read -p "Press enter to continue"
            ;;
        6) 
            echo "=== Audit Reports ==="
            echo "Generating audit reports..."
            audit_report
            read -p "Press Enter to continue..."
            ;;
        7) 
            echo "=== System Health Reports ==="
            echo "Generating system health reports..."
            system_health
            read -p "Press Enter to continue..."
            ;;
        8) 
            echo "=== System Health Reports ==="
            echo "Generating system health reports..."
            system_health
            read -p "Press Enter to continue..."
            ;; 
        q|Q) 
            echo "Exiting program..."
            exit 0
            ;;
        *) 
            echo "Invalid choice. Please try again."
            read -p "Press enter to continue"
            ;;      
    esac
done



