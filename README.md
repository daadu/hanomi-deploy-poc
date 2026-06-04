# Hanomi Deployment PoC

This is the main repo, for deploying Hanomi modules/services.

## Modules & services

- `frontend`: Next.js application on Linux
- `backend`: Go backend service on Linux
- `worker`: Python worker service on Windows

Currently the contract dependencies is `frontend -> backend -> worker`:
- An API called by `frontend` should always be handled by `backend`
- A job dispatched by `backend` should always be executed by `worker`
- The contract ownership and responsitlity is with the "right side" of the dependency chain. For eg. for `A -> B`, `B` is the contract owner, and `A` is the contract consumer.
- Therefore the deployment order (in case want to deploy multiple modules together) should be `worker -> backend -> frontend`, and they should be deployed in same order, 1 at a time.
- **IMPORTANT:** We should never do breaking changes (e.g. removing a field in API response in backend, or changing the signature of a function in worker) in the contracts. If want to drop the support for an old contract, we should deprecate it first and then remove it after a grace period.
- This way we ensure, we always have a working system, and we only do "rollback" for the module that failed to deploy. For eg: when we trigger a deploy all 3 modules together with new feature, and say `worker` got deployed, but `backend` failed to deploy, we only rollback `backend` to the previous version. The new deployed `worker` have new functionality but won't be invoke, and it will continue to work with older `backend`.

> Note: The alternate to handle failed deployment, when doing multiple module together would be to do full rollback, but that would be more time-consuming and given we have live traffic, it would be more risky. Instead incorporating the hard guideline of "never do breaking changes in contracts" and "deprecate first, remove later" would make the deployment process much simpler and safer.

> Note: When introducing new module, the contract dependency chain/graph should be re-evalauted and the deployment order should be adjusted accordingly.

## Repository structure

Each module have thier own directory, with their own "utility" scripts for building and deployment, manged by the platform team. These directory would also include the source as a git submodule. The directory name should have the module order (as per dependency chain) prefixed with a number, such that larger number depends on smaller number.

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
- `bootstrap.{sh,ps1,py}`: Bootstrap server, will be executed in server (linux or window VM)
- ??? TODO...

## Known limitation & further improvements


- Build/CI environment is always linux for now, since `worker` (only module that needs to be deployed on windows) is a python service, and there doesn't require any windows-specific dependencies while building.
- Local first approach - we should always be able to deploy from local machine, without needing to go through CI/CD pipeline. Then use same scripts in CI to deploy continously.
- ??? TODO