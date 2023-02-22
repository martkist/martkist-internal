MAKEOPTS=${MAKEOPTS:--j3}
DOCKEROPTS="--build-arg TAG=$MARTKIST_TAG --build-arg MAKEOPTS=$MAKEOPTS"

# echo "Building Linux release..."
# docker build $DOCKEROPTS -t martkist:release-linux-$MARTKIST_TAG -f release-linux.Dockerfile . 
# container_id=$(docker create "martkist:release-linux-$MARTKIST_TAG")
# docker cp "$container_id:/outputs" .
# docker rm "$container_id"

echo "Building Windows release..."
DOCKER_BUILDKIT=0 docker build $DOCKEROPTS -t martkist:release-win-$MARTKIST_TAG -f release-win.Dockerfile .
container_id=$(docker create "martkist:release-win-$MARTKIST_TAG")
docker cp "$container_id:/outputs/" .
docker rm "$container_id"

# echo "Building macOS release..."
# DOCKER_BUILDKIT=0 docker build $DOCKEROPTS -t martkist:release-macos-$MARTKIST_TAG -f release-macos.Dockerfile .
# container_id=$(docker create "martkist:release-macos-$MARTKIST_TAG")
# docker cp -q "$container_id:/outputs/" .
# docker rm "$container_id"

echo "Done!"