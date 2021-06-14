export APP=django
# Concurrent Build Specific
export BUILD_IMAGE_STREAM=django-psql-example

export SOURCE_STRAT_ENV=PIP_INDEX_URL
export SOURCE_STRAT_FROM_VERSION=latest
export SOURCE_STRAT_FROM=python
export POST_COMMIT_SCRIPT="./manage.py test"


export BUILD_IMAGE=image-registry.openshift-image-registry.svc:5000/svt-${app}/${BUILD_IMAGE_STREAM}
export GIT_URL=https://github.com/sclorg/django-ex.git
