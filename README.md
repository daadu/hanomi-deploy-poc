# Hanomi Deployment PoC

This is the main repo, for deploying Hanomi services.

## Services

- `frontend`: Next.js application running on Linux VM
- `backend`: Go backend service running on Linux VM
- `worker`: Python worker service running on Windows VM

Currently the contract dependencies is `frontend -> backend -> worker`:
- An API called by `frontend` should always be handled by `backend`
- A job dispatched by `backend` should always be executed by `worker`
- The contract ownership and responsitlity is with the "right side" of the dependency chain. For eg. for `A -> B`, `B` is the contract owner, and `A` is the contract consumer.
- Therefore the deployment order (in case want to deploy multiple services together) should be `worker -> backend -> frontend`, and they should be deployed in same order, 1 at a time.
- **IMPORTANT:** We should never do breaking changes (e.g. removing a field in API response in backend, or changing the signature of a function in worker) in the contracts. If want to drop the support for an old contract, we should deprecate it first and then remove it after a grace period.
- This way we ensure, we always have a working system, and we only do "rollback" for the service that failed to deploy. For eg: when we trigger a deploy all 3 services together with new feature, and say `worker` got deployed, but `backend` failed to deploy, we only rollback `backend` to the previous version. The new deployed `worker` have new functionality but won't be invoke, and it will continue to work with older `backend`.

> Note: The alternate to handle failed deployment, when doing multiple services together would be to do full rollback, but that would be more time-consuming and given we have live traffic, it would be more risky. Instead incorporating the hard guideline of "never do breaking changes in contracts" and "deprecate first, remove later" would make the deployment process much simpler and safer.

> Note: When introducing new service, the contract dependency chain/graph should be re-evalauted and the deployment order should be adjusted accordingly. The naming convention for the service directory, will force to think about the dependency chain while introducing new service.

## Repository structure

Each service have thier own directory, with their own "utility" scripts for building and deployment, manged by the platform team. These directory would also include the source as a git submodule at `./code`. The directory name should have the service order (as per dependency chain) prefixed with a number, such that larger number depends on smaller number.

```
1-worker/
├── code/ (git submodule)
├── build.sh
├── deploy.ps1
└── ...

2-backend/
├── code/ (git submodule)
├── build.sh
├── deploy.sh
└── ...

3-frontend/
├── code/ (git submodule)
├── build.sh
├── deploy.sh
└── ...
```

The required scripts are as follows:

- `build.sh`: Build artifact from code, will be executed in CI-runner (always linux). Output any artifact to `./build` directory.
- `deploy.{sh,ps1,py}`: Deploy artifact to server, will be executed in server (linux or window VM)
- ??? TODO...

## VM setup

Each VM will run only 1 service. VM could be either linux or windows, depending on the service requirements.

### Service directory structure

The `SERVICE_DIR` would be where all the required resources for the services are stored. It will be at `C:\Hanomi\<module-name>` on windows and `/opt/hanomi/<module-name>` on linux. For convience the VM should have an environment variable `SERVICE_DIR` pointing to this path.

The `SERVICE_DIR` would have following structure:

```
<SERVICE_DIR>/
├── releases/
│   └── ...
|   ├── 2026-01-01-123000-abc123/ (this is the "delpoyment-id", format: YYYY-MM-DD-HHMMSS-<release-id>)
|   ├── 2026-01-01-123100-abc123/
|   └── current -> 2026-01-01-123100-abc123 (symlink on linux, junction on windows)
├── config/ (configuration files, including secrets - this is configured manually by admin.)
│   ├── .env
│   ├── app.yaml
│   └── secrets.json
│   └── ...
├── scripts/ (utility scripts, copied here during deployment or bootstraping VM)
│   ├── deploy.ps1 (or deploy.sh for linux)
│   ├── bootstrap.ps1 (or bootstrap.sh for linux)
│   └── ...
└── ...
```

To get the current deployment id, we can read the `current` symlink/junction with - `basename "$(readlink $SERVICE_DIR/releases/current)"` in linux and `Split-Path (Resolve-Path "$SERVICE_DIR\releases\current").Path -Leaf` in windows.

### Daemonize service

The service should be daemonized using a process manager like `systemd` on linux or `NSSM` on windows.

The configuration should use the "current" symlink/junction to point to the current deployment directory.

The environement variables for the project should be either loaded by process manager if possible (e.g. `systemd` supports loading environment variables from a file), or should atleast set `SERVICE_DOTENV_FILES` environment variable to point to the `.env` files required for the application to run.


## Deployment flow

A deployment flow is for a specific service. It can be triggered manually (by admin in local machine) or automatically (by CI/CD pipeline).

The flow should follow these steps:
1. Determine if any changes in the "service directory" (script change or code submodule tag change)
2. If no changes, then exit (unless forced)
3. Determine the "release id" for this deployment, mostly the code submodule tag, unless named release is provided.
4. Determine the "deployment id", will be in format: `<YY-MM-DD-HHMMSS>-<release-id>`
5. Build the service, with `<service_dir>/build.sh`
6. Archive the built artifacts produced by the script at `<service_dir>/build`, so that can be transferred to VM, for eg ZIP
7. SCP the archive to the VM at right path: `<SERVICE_DIR>/releases/<deployment_id>.zip`
8. SCP the `deploy.ps1` (or `deploy.sh` for linux) script to the VM at right path: `<SERVICE_DIR>/scripts/deploy.ps1` - a copy of deploy script is intentionally kept in VM, in case manual usage is needed.
9. Remotely extract the archive to `<SERVICE_DIR>/releases/<deployment_id>`: for eg `ssh <user>@<host> "cd <SERVICE_DIR>/releases/<deployment_id> && unzip <deployment_id>.zip"`
10. Remotely execute the deploy script: `ssh <user>@<host> "cd <SERVICE_DIR>/scripts && bash -o pipefail -c \"./deploy.sh '<deployment_id>' 2>&1 | tee deploy.<deployment_id>.log\""`
    1. records the current deployment id (will be used for rollback if needed) as `prev_deployment_id`
    2. run any "pre-deploy" steps - like migrations, backups, etc.
    3. creates/update a symlink/join such that, `<SERVICE_DIR>/release/current` points to `<SERVICE_DIR>/release/<deployment_id>`
    4. restarts the service
    5. probes that the service is running - health check, sanity check
    6. probe successful - then script exits(0)
    7. initate rollback to `prev_deployment_id`
    8. run any "rollback" steps - like migrations rollback (reverse migration), etc.
    9. creates/update a symlink/join such that, `<SERVICE_DIR>/release/current` points to `<SERVICE_DIR>/release/<prev_deployment_id>`
    10. restarts the service
    11. probes that the service is running - health check, sanity check
    12. probe successful - then script exits(0)
    13. script exits(1) - should break the CI/CD pipeline as well

### Notes on migration

- Migrations should be written and applied using a "migration framework" (e.g. Flyway, Liquibase, etc.)
- Should be possible to reverse the migration (rollback) safely, without data loss.
- Since this is dependent on how service implements this, it should be documented and have clear instructions (preferrable have scripts/commands avaiable for it as well) on how to (a) migrate, (b) either know in order how new migrations will be applied, so could be rollbacked in sequence OR if the migration table keeps track of "batch number" then should be able to know last batch number, (c) rollback specific migration or batch (based on what is available).
- Each migration should be atomic and idempotent - should be able to run multiple times without causing any issues.
- Migration should execute fast - should not block the deployment process for too long.
- Avoid doing large data mutations here, instead do it with one-off scripts/commands, executed manually by admin post deployment. In this case, since we are doing data mutation post-deployment, ensure that the code supports pre-data migration, in-data migration, and post-data migration phases. For eg if a new field like `stripe_subscription_id` is added, and we need to populate it (and might take time, due to API quota etc), our code should not be affected whether the field is populated or not. If required, the code should "compute this field" on demand for it's logic. Such migration should be carefully planned with the release and communicated to the platform/ops team. Such data migrations, usually need to be executed non-atomically with idempotent operations.

---

## Appendix

### Principles followed

- Idempotent - the deployment script should be able to run multiple times without causing any issues.
- Local first (aka Script first, CI later) - we should always be able to deploy from local machine, without needing to go through CI/CD pipeline. Then use same scripts in CI to deploy continously.
- Vendor neutral - should be easy to switch between different vendors (e.g. from Github Actions to Gitlab CI, or from AWS to Azure).
- Minimal viable abstraction - use minimal tools and avoid unnecessary complexity - unless justified. Trade complexity for simplicity, with clear reasoning.
- Robust - ensure that failures are handled gracefully and the system is always in a consistent "correct" state.

### Known limitation & further improvements

- Build/CI environment is always linux for now, since `worker` (only module that needs to be deployed on windows) is a python service, and there doesn't require any windows-specific dependencies while building.
- Currently the setup is for single replica deployment only. To support that in future, we need to break deployment flow into deploy-prepare and deploy-switch stages. "prepare" all nodes first, then switch to "current" directory (recommended that we do this with below point).
- Currently we deploy directly by switching the "current" symlink/junction, and then do the probing to check if to commit or rollback. This can be improved, by having a "next" / "preview" directory to deploy to, do the probing against it first without sending real traffic and then do the switching to "current" directory. For now we assume that the releases are well tested, in case the team grows and releases become more frequent, this should be done.
- Currently we are using bash and powershell scripts as the main "tool" for deployment. If becomes too complex, we should consider either using proper langage like python or if possible use a tool like ansible.
- VM provisioning and other infrastructure setup is not covered in this deployment flow, and should be handled separately (e.g. using terraform or other infrastructure as code tools). However highly recommend we create a `bootstrap.sh` script for each service to setup the VM from scratch. So that in future if we need to spin up new VMs, we can use this script to setup the VM.
- A seperate VM cleanup script (or could be included with the deployment flow) ran periodically, to remove old releases and keep only the last 10 (configurable) releases.
- Windows server have OpenSSH configured with Powershell by default.