export APP=eap-app
# Concurrent Build Specific
export BUILD_IMAGE_STREAM=jboss-eap64-openshift
export SOURCE_STRAT_ENV=""
export SOURCE_STRAT_FROM_VERSION=latest
export SOURCE_STRAT_FROM=jboss-eap64-openshift
export POST_COMMIT_SCRIPT=""

export BUILD_IMAGE=image-registry.openshift-image-registry.svc:5000/svt-${app}/${BUILD_IMAGE_STREAM}
export GIT_URL=https://github.com/jboss-openshift/openshift-quickstarts
