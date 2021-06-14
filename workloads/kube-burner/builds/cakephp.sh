export app=cakephp
# Concurrent Build Specific
export BUILD_IMAGE_STREAM=cakephp-mysql-example

export source_strat_env=COMPOSER_MIRROR
export source_strat_from_version=latest

export source_strat_from=php
export post_commit_script=./vendor/bin/phpunit


export build_image=image-registry.openshift-image-registry.svc:5000/svt-${app}/${BUILD_IMAGE_STREAM}
export git_url=https://github.com/sclorg/cakephp-ex.git
