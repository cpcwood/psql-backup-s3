# Backup PSQL Database to AWS S3

Perform rotating encrypted backups of a PostgreSQL database using AWS S3 and Linux cron or Kubernetes CronJob. 

## Setup

### Create AWS S3 Bucket

Create a private Amazon AWS S3 bucket to store your database backups:

[https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-bucket.html](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-bucket.html)

### Create IAM User

Create an IAM in your AWS account with access to the S3 bucket created above: [https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)

The S3 policy might look like:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::<bucket-id>/*"
        }
    ]
}
```

## Setup

### Copy script to system

Copy script to system, change permissions using chmod to make script executable but not read or writable by general users

### Setup Cron

Depending on your deployment setup, there will different ways run the backup script on a regular interval. 

Here are the setup methods for two typical deployment types:

- traditional vm - Linux cron
- kubernetes - CronJob

#### Linux cron

cron is a time-based job scheduler built into Linux, and it can be used to run processes on the system at scheduled times.

##### Config

Store config in environment variables

#### Kubernetes CronJob

Use CronJob

##### Config

Use kubernetes secrets to store env



## License

MIT
