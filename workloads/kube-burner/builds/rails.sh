export APP=rails-postgresql-example
# Concurrent Build Specific
export BUILD_IMAGE_STREAM=rails-postgresql-example

export SOURCE_STRAT_ENV=RUBYGEM_MIRROR
export SOURCE_STRAT_FROM_VERSION=latest
export SOURCE_STRAT_FROM=ruby
export POST_COMMIT_SCRIPT="bundle exec rake test"


export BUILD_IMAGE=image-registry.openshift-image-registry.svc:5000/svt-${app}/${BUILD_IMAGE_STREAM}
export GIT_URL=https://github.com/sclorg/rails-ex.git
