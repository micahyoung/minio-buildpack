# Minio Buildpack 

Cloud Foundry Buildpack providing [minio server storage](https://www.minio.io/)

## Usage

### Amazon S3 Edge Caching

Create a single gateway app instance - backed by an Amazon S3 cluster 

#### Limitations

* Only works when apps have public internet access
* Cache space is limited to instance capacity

#### Initialization
```
MINIO_ACCESS_KEY="<aws access key>"
MINIO_SECRET_KEY="<aws secret key>"
MINIO_CACHE_DRIVES="/var/vcap/app/data"
MINIO_CACHE_EXCLUDE="bucket1/*;*.png"
MINIO_CACHE_EXPIRY=40
MINIO_CACHE_MAXUSE=80
HOSTNAME=""
CF_DOMAIN=""
INIT_DIR=$(dirname $(mktemp $(mktemp -d)/XXX))

cf push s3-storage \
  -c 'minio gateway s3 --address :$PORT' \
  -b https://github.com/micahyoung/minio-buildpack.git \
  -k 4GB \
  -m 256MB \
  -p $INIT_DIR \
  -u process \
  --no-start \
  --hostname $HOSTNAME -d $CF_DOMAIN \
  ;

cf set-env s3-storage MINIO_ACCESS_KEY $MINIO_ACCESS_KEY
cf set-env s3-storage MINIO_SECRET_KEY $MINIO_SECRET_KEY
cf set-env s3-storage MINIO_CACHE_DRIVES $MINIO_CACHE_DRIVES
cf set-env s3-storage MINIO_CACHE_EXCLUDE $MINIO_CACHE_EXCLUDE
cf set-env s3-storage MINIO_CACHE_EXPIRY $MINIO_CACHE_EXPIRY
cf set-env s3-storage MINIO_CACHE_MAXUSE $MINIO_CACHE_MAXUSE

cf start s3-storage
```

### Single instance

Create a single storage app instance

#### Limitations

* All data will be lost on restart, scale or crash
* Storage space is limited to instance capacity

#### Initialization
```bash
ACCESS_KEY=""
SECRET_KEY=""
HOSTNAME=""
CF_DOMAIN=""
INIT_DIR=$(dirname $(mktemp $(mktemp -d)/XXX))

cf push s3-storage \
  -b https://github.com/micahyoung/minio-buildpack.git \
  -k 4GB \
  -m 256MB \
  -p $INIT_DIR \
  -u process \
  --no-start \
  --hostname $HOSTNAME -d $CF_DOMAIN \
  ;


cf set-env s3-storage MINIO_ACCESS_KEY $ACCESS_KEY
cf set-env s3-storage MINIO_SECRET_KEY $SECRET_KEY

cf start s3-storage
```

### 4-node Cluster with Gateway

Create a cluster of 5 app instances (1 gateway, 4 storage apps x 1 instances). This configuration allows you to scale and refresh storage instances instances over time, without downtime.

#### Limitations
* Permanent data loss occurs if more than n/2 instances are down (stopped/restarted).
* Use only for emphemeral data - a more robust solution with a persistent storage and backups should be used otherwise.
* Gateway needs app-0/instance-0 to be up at all times.
* 4 instances is the minimum minio cluster size and therefore mininimally robust to failures.
* Minio requires at least N/2 instances up to maintain read-only access and prevent data loss.
* Minio requires at least N/2+1 instances up to maintain write access.
* Instance count cannot be increased without recreating the cluster.
* Recovery requires manual healing ([see below](#healing-instances)).
* See minio docs for additional options and limitations [minio distributed quick-start guide](https://docs.minio.io/docs/distributed-minio-quickstart-guide.html)

#### Initialization
```bash
ACCESS_KEY=""
SECRET_KEY=""
HOSTNAME=""
CF_DOMAIN=""
INIT_DIR=$(dirname $(mktemp $(mktemp -d)/XXX))

for app in s3-storage-{0..3}; do
  cf push $app \
    --hostname $app -d apps.internal \
    -c 'minio server http://0.s3-storage-{0...3}.apps.internal/home/vcap/app/shared' \
    -i 1 \
    -k 4GB \
    -m 1GB \
    -u process \
    --no-start \
    -b https://github.com/micahyoung/minio-buildpack.git \
    -p $INIT_DIR \
    ;
done

cf push s3-storage-gateway \
  -c 'minio gateway s3 http://0.s3-storage-0.apps.internal:9000 --address :$PORT' \
  -k 128MB \
  -m 128M \
  -u process \
  -n $HOSTNAME \
  -d $CF_DOMAIN \
  --no-start \
  -b https://github.com/micahyoung/minio-buildpack.git \
  -p $INIT_DIR \
  ;

for app in s3-storage-{0..3} s3-storage-gateway; do
  cf set-env $app MINIO_ACCESS_KEY $ACCESS_KEY
  cf set-env $app MINIO_SECRET_KEY $SECRET_KEY
done

cf set-env s3-storage-gateway MINIO_DOMAIN $HOSTNAME.$CF_DOMAIN 

for src in s3-storage-{0..3} s3-storage-gateway; do
  for dst in s3-storage-{0..3}; do
    cf add-network-policy $src \
      --destination-app $dst \
      --port 9000 --protocol tcp \
      ;
  done
done

for app in s3-storage-{0..3}; do
  cf start $app &
done

wait

cf start s3-storage-gateway
```

#### Healing instances

Restarting or changing any instance requires a manually `heal` process using the distributed `mc` binary.

```bash
cf scale -k 8GB s3-storage-1
cf ssh s3-storage-1
$ deps/0/bin/mc config host add local http://localhost:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
$ deps/0/bin/mc admin heal local
$ deps/0/bin/mc admin info local
```

Note: Minio does not automatically rebalance data after node recreation. [more](https://github.com/minio/minio/issues/3478#issuecomment-268203660). Consider using mc mirror` afterwards to download then overwrite.

### Create a bucket via cf task
```bash
cf run-task s3-storage \
  'mc config host add local http://localhost:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY \
  && mc mb local/my-bucket \
  && mc policy download local/my-bucket'

cf logs s3-storage --recent
#   2018-09-11T16:52:56.81-0400 [APP/TASK/73306ae0/0] OUT Added `local` successfully.
#   2018-09-11T16:52:56.83-0400 [APP/TASK/73306ae0/0] OUT Bucket created successfully `local/my-bucket`.
#   2018-09-11T16:52:56.84-0400 [APP/TASK/73306ae0/0] OUT Access permission for `local/my-bucket` is set to `download`
#   2018-09-11T16:52:56.84-0400 [APP/TASK/73306ae0/0] OUT Exit status 0
```

### Backup/restore

Backups and restores can be performed using the `mc mirror` commands on a machine *outside* the cluster.

First, alias the public s3 url
```bash
mc config host add cluster https://public-s3-hostname.my-domain.net $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
```

Backup:
```bash
mc mirror cluster/ local-backup-dir/
```

Restore (will also rebalance after `heal`):
```bash
mc mirror --overwrite local-backup-dir/ cluster/ 
```

## Development

### Building the Buildpack
To build this buildpack, run the following command from the buildpack's directory:

1. Source the .envrc file in the buildpack directory.
```bash
source .envrc
```
To simplify the process in the future, install [direnv](https://direnv.net/) which will automatically source .envrc when you change directories.

1. Install buildpack-packager
```bash
./scripts/install_tools.sh
```

1. Build the buildpack
```bash
buildpack-packager build
```

1. Use in Cloud Foundry
Upload the buildpack to your Cloud Foundry and optionally specify it by name

```bash
cf create-buildpack [BUILDPACK_NAME] [BUILDPACK_ZIP_FILE_PATH] 1
cf push my_app [-b BUILDPACK_NAME]
```

### Testing
Buildpacks use the [Cutlass](https://github.com/cloudfoundry/libbuildpack/cutlass) framework for running integration tests.

To test this buildpack, run the following command from the buildpack's directory:

1. Source the .envrc file in the buildpack directory.

```bash
source .envrc
```
To simplify the process in the future, install [direnv](https://direnv.net/) which will automatically source .envrc when you change directories.

1. Run unit tests

```bash
./scripts/unit.sh
```

1. Run integration tests

```bash
./scripts/integration.sh
```

More information can be found on Github [cutlass](https://github.com/cloudfoundry/libbuildpack/cutlass).

### Reporting Issues
Open an issue on this project

## Disclaimer
This buildpack is experimental and not yet intended for production use.
