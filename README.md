# PSQL Database Backup to AWS S3

Perform scheduled encrypted backups of a PostgreSQL database to AWS S3, in a virtual machine using Linux cron, or Kubernetes cluster using CronJob. The script provides the option to set a backup rotation period.

## Setup AWS

### Create AWS S3 Bucket

Create a private Amazon AWS S3 bucket to store your database backups: [AWS 'create bucket' guide](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-bucket.html).

### Create IAM User

Create an IAM user in your AWS account with access to the S3 bucket created above: [AWS 'create user' guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)

The script requires, list, put, and delete access on the s3 bucket. So the S3 policy JSON attached to the IAM user might look like:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::<bucket-name>/*",
                "arn:aws:s3:::<bucket-name>"
            ]
        }
    ]
}
```

Make sure to download or keep hold of the new user security credentials so you can add them to the backup script environment later.

## Create PGP Keys

On a separate (ideally air-gapped) machine, install [GPG](https://gnupg.org/) so encryption keys can be generated:

```sh
apk add gnupg
```

Then create a pair of public and private encryption keys. Using public-key cryptography to encrypt the backup on the server will help prevent the database backup from being compromised if the environment variables are leaked.

- Generate a keypair using your email for ID: ```gpg --gen-key```
- Export the public key: ```gpg --armor --export <your-email>```
- Export the secret key and move to [secure storage](https://lwn.net/Articles/734767/).

## Deploy

Depending on your deployment setup, there will be different ways to deploy the script to run the backup job regularly.

Here are the setup methods for two typical deployment types:
- Traditional VM - Linux cron
- Kubernetes - CronJob

## Traditional VM

### Copy Script to Machine

Copy script to machine and make sure it is executable for the crontab user:

```sh
chmod 744 ./psql-backup-s3.sh
```

### Install Dependencies

Install script dependencies on VM using package manager:

- **GPG** - Install [GPG](https://gnupg.org/) to encrypt backup files: ```apk add gnupg```
- **AWS-CLI** - Install AWS CLI tool to transfer backup to AWS S3: ```apk add aws-cli``` or see [AWS guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html)
- **date** - Ensure date is GNU core utilities date, not included in alpine linux (busybox) by default: ```apk add coreutils```

### Linux cron

cron is a time-based job scheduler built into Linux which runs processes on the system at scheduled times.

#### Config

The backup script gets its configuration from environment variables. The variables required can be seen in [```templates/psql-backup-s3.env```](/templates/psql-backup-s3.env).

cron jobs do not inherit the same environment as a job run from the command line. Instead, their default environment is from ```/etc/environment```, read more about why in [this IBM article](https://www.ibm.com/support/pages/cron-environment-and-cron-job-failures). Therefore, load the environment variables required for the backup script in the job definition.

One way to do this <i>source</i> a shell script using the ["dot" command](https://tldp.org/LDP/abs/html/special-chars.html#DOTREF) in the crontab.

First, create a script exporting the required environment variables, example in [```templates/psql-backup-s3.env```](/templates/psql-backup-s3.env).

Since it contains credentials, ensure the only the crontab user can only access it:

```sh
chmod 700 psql-backup-s3.env
```

It can then be sourced before the backup job in the crontab, as shown below.

#### Create the cron Job

Add a new cron job using crontab. The job should periodically load the environment variables and then run the backup script. For example, to run the backup daily at 3.30 am:

```sh
crontab -e
```

```sh
30 3 * * * . $HOME/psql-backup-s3/psql-backup-s3.env && $HOME/psql-backup-s3/psql-backup-s3.sh 2>&1 | logger -t psql-backup-s3
```
For more info on setting up a job using crontab, checkout [ubuntu's guide here](https://help.ubuntu.com/community/CronHowto). [crontab guru](https://crontab.guru/) can be helpful for defining schedules.

## Kubernetes CronJob

[Kubernetes CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) is a built-in feature which allows jobs to be run in containers periodically.

### Config

Create a [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/) object to store the sensitive credentials for the backup script. A template can be seen in: [```templates/psql-backup-s3.secret.yaml```](templates/psql-backup-s3.secret.yaml)

Create a [Kubernetes ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) object to store the non-sensitive configuration details for the script. A template can be seen in: [```templates/psql-backup-s3.config.yaml```](templates/psql-backup-s3.config.yaml)

Make sure to [apply](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/) the newly created secret and config objects to your cluster in the correct namespace.

### Create the CronJob

Create a [Kubernetes CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) object to run the backup job on a schedule. A template can be seen in: [```templates/psql-backup-s3.cronjob.yaml```](templates/psql-backup-s3.cronjob.yaml). The [```Dockerfile```](Dockerfile) included in the repo will build a container image with the required dependencies to run the script. It can be pulled from dockerhub under the repository [```cpcwood/psql-backup-s3```](https://hub.docker.com/r/cpcwood/psql-backup-s3)

[Apply](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/) the newly created CronJob object to your cluster.

The job should now run the backup script periodically as scheduled in the object definition.

## Restore

To restore backup:
- Download the encrypted database dump from aws S3
- Copy to the machine containing the private gpg key
- Decrypt downloaded file using gpg: ```gpg --output <decrypted file name>.sql.bz2 --decrypt <downloaded file name>.sql.bz2.gpg```
- Move to server hosting PostgreSQL database
- Unzip decrypted file using bzip: ```bzip2 -d <decrypted file name>.sql.bz2```
- Restore the database dump using the ```psql``` command, for details see the documentation on [backup dumps](https://www.postgresql.org/docs/current/backup-dump.html) for your version of PostgreSQL.

## License

MIT
