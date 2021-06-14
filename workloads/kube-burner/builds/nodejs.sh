export APP=nodejs-mongodb-example
# Concurrent Build Specific
export BUILD_IMAGE_STREAM=nodejs-mongodb-example

export SOURCE_STRAT_ENV=''
export SOURCE_STRAT_FROM_VERSION=latest
export SOURCE_STRAT_FROM=nodejs
export POST_COMMIT_SCRIPT=""


export BUILD_IMAGE=image-registry.openshift-image-registry.svc:5000/svt-${app}/${BUILD_IMAGE_STREAM}
export GIT_URL=https://github.com/openshift/nodejs-ex.git
