#!/bin/sh
# PSQL Database Backup (Local Only with pg_dumpall)

echo "Starting PSQL Database Backup..."

# Ensure all required environment variables are present
if [ -z "$POSTGRES_PASSWORD" ] || \
    [ -z "$POSTGRES_USER" ] || \
    [ -z "$POSTGRES_HOST" ]; then
    >&2 echo 'Required variable unset, database backup failed'
    exit 1
fi

# Create backup params
backup_dir=$(mktemp -d)
backup_name=$(date +%d'-'%m'-'%Y'--'%H'-'%M'-'%S).sql.bz2
backup_path="$backup_dir/$backup_name"

# Create and compress the backup using pg_dumpall
PGPASSWORD=$POSTGRES_PASSWORD pg_dumpall -U "$POSTGRES_USER" -h "$POSTGRES_HOST" | bzip2 > "$backup_path"

# Check backup created
if [ ! -e "$backup_path" ]; then
    echo "Backup file not found"
    exit 1
fi

# Indicate if backup was successful
if [ $? -eq 0 ]; then
    echo "PSQL database backup: '$backup_name' completed and saved locally"

else
    echo "PSQL database backup: '$backup_name' failed"
    exit 1
fi

# Optionally, you can add functionality for removing local backups after a certain period
# This is a simple example: remove backups older than 7 days
rotation_period_days=$ROTATION_PERIOD
rotation_period_seconds=$((rotation_period_days * 24 * 60 * 60))
current_time=$(date +%s)

# Iterate through files in backup directory and remove those older than the rotation period
for file in "$backup_dir"/*.sql.bz2; do
    file_time=$(date -r "$file" +%s)
    if [ $((current_time - file_time)) -gt $rotation_period_seconds ]; then
        rm "$file"
    fi
done

# Remove the temporary backup directory if you don't want to retain it
rm -rf "$backup_dir"