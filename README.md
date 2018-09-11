# Minio Buildpack 

Cloud Foundry Buildpack providing minio server storage

## Usage

### Single instance

Create a single storage app instance

#### Limitations

* All data will be lost on restart or crash
* Storage space is limited to instance capacity
```
ACCESS_KEY=""
SECRET_KEY=""
HOSTNAME=""
CF_DOMAIN=""
INIT_DIR=$(dirname $(mktemp $(mktemp -d)/XXX))

cf push s3-storage \
  -b https://github.com/micahyoung/minio-buildpack.git \
  -k 4GB \
  -m 128MB \
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

Create a cluster of 5 app instances (1 gateways, 2 storage apps x 2 instances). This configuration allow you to increase storage, node count and upgrade instances over time, without downtime (a more robust solution wiht a full backup option should be used for non-ephemeral data).

#### Limitations
* Example below is the minimum minio cluster size.
* Gateway points to app-0/instance-0 which must be up for public access
* Minio requires N/2 instances up to maintain read-only access and prevent data loss.
* Minio requires N/2+1 instances up to maintain write access which will *not* be true if one app is down. Increase app instance count to prevent this.
* See minio docs for additional options and limitations [minio distributed quick-start guide](https://docs.minio.io/docs/distributed-minio-quickstart-guide.html)

```
ACCESS_KEY=""
SECRET_KEY=""
HOSTNAME=""
CF_DOMAIN=""
INIT_DIR=$(dirname $(mktemp $(mktemp -d)/XXX))

for app in s3-storage-{0..1}; do
  cf push $app \
    --hostname $app -d apps.internal \
    -c 'minio server http://{0...1}.s3-storage-{0...1}.apps.internal/home/vcap/app/shared' \
    -i 2 \
    -k 4GB \
    -m 128MB \
    -u process \
    --no-start \
    -b https://github.com/micahyoung/minio-buildpack.git \
    -p $INIT_DIR \
    ;
done

cf push s3-storage-gateway \
  -c 'minio gateway s3 http://0.s3-storage-0.apps.internal:9000 --address :$PORT' \
  -m 128M \
  -u process \
  -n $HOSTNAME \
  -d $CF_DOMAIN \
  --no-start \
  -b https://github.com/micahyoung/minio-buildpack.git \
  -p $INIT_DIR \
  ;

for app in s3-storage-{0..1} s3-storage-gateway; do
  cf set-env $app MINIO_ACCESS_KEY $ACCESS_KEY
  cf set-env $app MINIO_SECRET_KEY $SECRET_KEY
done

cf set-env s3-storage-gateway MINIO_DOMAIN $HOSTNAME.$CF_DOMAIN 

for src in s3-storage-{0..1} s3-storage-gateway; do
  for dst in s3-storage-0 s3-storage-1; do
    cf add-network-policy $src \
      --destination-app $dst \
      --port 9000 --protocol tcp \
      ;
  done
done

for app in s3-storage-{0..1} s3-storage-gateway; do
  cf start $app 
done
```

### Update process

Restarting or changing any instance requires a manually `heal` process using the distributed `mc` binary

```
cf scale -k 8GB s3-storage-1
cf ssh s3-storage-1
$ deps/0/bin/mc config host add local http://localhost:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
$ deps/0/bin/mc admin heal local
$ deps/0/bin/mc admin info local
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
