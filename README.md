# PSQL Database Backup to AWS S3

Perform encrypted rotating backups of a PostgreSQL database using AWS S3 and Linux cron or Kubernetes CronJob. 

## Setup AWS

### Create AWS S3 Bucket

Create a private Amazon AWS S3 bucket to store your database backups: 
[https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-bucket.html](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-bucket.html)

### Create IAM User

Create an IAM in your AWS account with access to the S3 bucket created above: 

[https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)

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

## Create PGP Keys

On a separate (ideally air-gapped) machine, install GPG so encryption keys can be generated:

```sh
apk add gnupg
```

Then create a public/private pair of GPG keys using [GPG](https://gnupg.org/). Using a public key to encrypt the backup on the server will help prevent the database backup being compromised if the environment variables in the backup script are leaked.

Generate key using email for ID:
```sh
gpg --gen-key
```

Get public key id using list keys:
```sh
gpg --list-keys
```

Export public key and convert into string which can be used as env variable:
```sh
gpg --armor --export <your-email> | cat -e | sed 's/\$/\\n/g'
```

Export secret key to file and move to [secure storage](https://lwn.net/Articles/734767/).

## Add to System

Depending on your deployment setup, there will different ways run the backup script on a regular interval. 

Here are the setup methods for two typical deployment types:

- Traditional VM - Linux cron
- Kubernetes - CronJob

## Traditional VM

### Copy script to system

Copy script to system and make sure it is executable for the crontab user chmod:

```sh
chmod 744 <filename>
```

### Install Dependencies

Install script dependencies on VM using package manager.
#### GPG

Install [GPG](https://gnupg.org/) to encrypt backup files:

```sh
apk add gnupg
```

#### AWS-CLI

Install AWS CLI tool to transfer backup to AWS S3:

```sh
apk add aws-cli
```

#### date

Ensure date is GNU core utilities date, not included in alpine linux (busybox) by default:

```sh
apk add coreutils
```

### Linux cron

cron is a time-based job scheduler built into Linux, and it can be used to run processes on the system at scheduled times.

### Config

The backup script gets its configuration from environment variables. The variables required can be seen in [```templates/psql-backup-s3.env```](/templates/psql-backup-s3.env).

cron jobs do not inherit the same environment as a job run from the command line, instead their default environment is from ```/etc/environment```, read more about why in [this IBM article](https://www.ibm.com/support/pages/cron-environment-and-cron-job-failures). Therefore, the environment variables required for the backup script's config need to be loaded specially in the job definition.

One way to do this <i>source</i> a shell script using the ["dot" command](https://tldp.org/LDP/abs/html/special-chars.html#DOTREF) in the crontab.

First create the script containing the environment exports, example in [```templates/psql-backup-s3.env```](/templates/psql-backup-s3.env).

Since it contains credentials, ensure it can only be read by the crontab user:

```sh
chmod 700 psql-backup-s3.env
```

It can then be sourced before the backup job in the crontab as shown below.

#### Create the cron job

Add a new cron job using crontab. The job should periodically load the environment variables and then run the backup script. For example, to run the backup daily at 3.30am:

```sh
crontab -e
```

```sh
30 3 * * * . $HOME/psql-backup-s3/psql-backup-s3.env; $HOME/psql-backup-s3/psql-backup-s3.sh
```

For more info on how to setup job using crontab, checkout [ubuntu's guide here](https://help.ubuntu.com/community/CronHowto)

## Kubernetes CronJob

[Kubernetes CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) is a built in feature which allows jobs to be run on repeating schedule.

### Config

Create a [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/) object to store the sensitive credentials for the backup script. A template can be seen in: [```templates/psql-backup-s3.secret.yaml```](templates/psql-backup-s3.secret.yaml)

Create a [Kubernetes ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) object to store the non-sensitive configuration details for the script. A template can be seen in: [```templates/psql-backup-s3.config.yaml```](templates/psql-backup-s3.config.yaml)

Make sure to [apply](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/) the newly created to your cluster in the correct namespace.

### Create the CronJob

Create a [Kubernetes CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) object to run the backup job on a schedule. A template can be seen in: [```templates/psql-backup-s3.cronjob.yaml```](templates/psql-backup-s3.cronjob.yaml)

[Apply](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/) the CronJob object to your cluster.

The job should now run the backup script periodically as scheduled in the object definition.

## Restore

Download encrypted db dump

Import private key to gpg

decrypt file using gpg

restore db from dump using psql


## License

MIT
