#! /bin/sh
# PSQL Database Backup to AWS S3

echo "Starting PSQL Database Backup..."

# Ensure all required environment variables are present
if [ -z "$GPG_KEY" ] || \
    [ -z "$GPG_KEY_ID" ] || \
    [ -z "$POSTGRES_PASSWORD" ] || \
    [ -z "$POSTGRES_USER" ] || \
    [ -z "$POSTGRES_HOST" ] || \
    [ -z "$POSTGRES_DB" ] || \
    [ -z "$AWS_ACCESS_KEY_ID" ] || \
    [ -z "$AWS_SECRET_ACCESS_KEY" ] || \
    [ -z "$AWS_DEFAULT_REGION" ] || \
    [ -z "$S3_BUCKET" ]; then
    >&2 echo 'Required variable unset, database backup failed'
    exit 1
fi

# Make sure local bin in path
export PATH=/usr/local/bin:$PATH

# Import gpg public key from env
echo "$GPG_KEY" | gpg --batch --import

# Create backup params
backup_dir=$(mktemp -d)
backup_name=$POSTGRES_DB'--'$(date +%d'-'%m'-'%Y'--'%H'-'%M'-'%S).sql.bz2.gpg
backup_path="$backup_dir/$backup_name"

# Create, compress, and encrypt backup
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -d "$POSTGRES_DB" -U "$POSTGRES_USER" -h "$POSTGRES_HOST" | bzip2 | gpg --batch --recipient "$GPG_KEY_ID" --trust-model always --encrypt --output "$backup_path"

# Check backup created
if [ ! -e "$backup_path" ]; then
    echo 'Backup file not found'
    exit 1
fi

# Push backup to S3
aws s3 cp "$backup_path" "s3://$S3_BUCKET"
status=$?

# Remove tmp backup path
rm -rf "$backup_dir"

# Indicate if backup was successful
if [ $status -eq 0 ]; then
    echo "PSQL database backup: '$backup_name' completed to '$S3_BUCKET'"

    # Remove expired backups from S3
    if [ "$ROTATION_PERIOD" != "" ]; then
        aws s3 ls "$S3_BUCKET" --recursive | while read -r line;  do
            stringdate=$(echo "$line" | awk '{print $1" "$2}')
            filedate=$(date -d"$stringdate" +%s)
            olderthan=$(date -d"-$ROTATION_PERIOD days" +%s)
            if [ "$filedate" -lt "$olderthan" ]; then
                filetoremove=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//')
                if [ "$filetoremove" != "" ]; then
                    aws s3 rm "s3://$S3_BUCKET/$filetoremove"
                fi
            fi
        done
    fi
    
else
    echo "PSQL database backup: '$backup_name' failed"
    exit 1
fi
