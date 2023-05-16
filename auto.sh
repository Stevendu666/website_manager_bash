
#!/bin/bash

# Set variables
INTRANET_DIR="/var/www/html/intranet"
LIVE_DIR="/var/www/html/live"
BACKUP_DIR="/var/www/html/backups"
LOG_FILE="/var/log/site.log"
USERNAME="$(whoami)"
NOW="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_TIME="02:00" # Specify backup time here (24-hour format)
AUDIT_DIR="/var/www/audit"

# Define the environment variables


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
    cat $tmp_file >> $LOG_FILE

    # Sync the changes to the Live directory
    sudo rsync -av --delete $INTRANET_DIR/ $LIVE_DIR/

    echo "Changes synced to Live directory."
  fi

  # Remove the temporary file
  rm $tmp_file
}

# Backup Intranet directory
function backup_intranet() {
  # Create backup directory if it doesn't exist
  if [ ! -d "$BACKUP_DIR/$NOW/intranet" ]; then
    sudo mkdir -p "$BACKUP_DIR/$NOW/intranet"
  fi

  # Check if the backup directory was created successfully
  if [ ! -d "$BACKUP_DIR/$NOW/intranet" ]; then
    sudo echo "Error: Failed to create backup directory."
    return 1
  fi

  # Backup and compress the Intranet directory
  sudo tar -czf "$BACKUP_DIR/intranet/$NOW/Intranet-archive-$(date +%Y-%m-%d).zip" "$INTRANET_DIR/"

  echo "Backup completed."
}

# Backup Live directory
function backup_live() {
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
  sudo tar -czf "$BACKUP_DIR/live/$NOW/Live-archive-$(date +%Y-%m-%d).zip" "$LIVE_DIR/"

  echo "Backup completed."
}


# Function to monitor Intranet directory for changes
function monitor_intranet {
  echo "Monitoring Intranet Directory for changes..."
  inotifywait -m -e modify,create,delete "$INTRANET_DIR" --exclude '^\..*' |
  while read path action file; do
    echo "Detected change in $path$file: $action"
    sudo echo "$(date +"%Y-%m-%d %H:%M:%S") - User $USERNAME $action file '$file' on $path" >> "$LOG_FILE"
  done
}

0 1 * * * /home/steven/Documents/Scripting/auto.sh