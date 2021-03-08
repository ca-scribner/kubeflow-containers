# Tag images with standard tags

# End repo with exactly one trailing slash, unless it is empty
REPO=$(echo "${REPO}" | sed 's:/*$:/:' | sed 's:^\s*/*\s*$::') ;\

REPO_IMAGE_NAME="${REPO}${IMAGE_NAME}"
ORIGINAL_IMAGE_NAME="${REPO_IMAGE_NAME}:${TAG}"
echo "Adding tags to $ORIGINAL_IMAGE_NAME"

SHORT_SHA=$(echo "${GIT_SHA}" | cut -c1-8)  # first 8 characters of SHA
echo "Tagging with SHORT_SHA ($SHORT_SHA)"
docker tag $ORIGINAL_IMAGE_NAME $REPO_IMAGE_NAME:$SHORT_SHA

BRANCH_NAME=${BRANCH_NAME:-git rev-parse --abbrev-ref HEAD}
echo "Tagging with BRANCH_NAME ($BRANCH_NAME)"
docker tag $ORIGINAL_IMAGE_NAME $REPO_IMAGE_NAME:$BRANCH_NAME