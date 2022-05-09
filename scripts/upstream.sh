#!/usr/bin/env bash
# get base dir regardless of execution location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
. $(dirname $SOURCE)/init.sh

git submodule update --init --recursive

if [[ "$1" == up* ]]; then
    (
        cd "$basedir/Airplane/"
        git fetch origin ver/1.16 && git reset --hard origin/ver/1.16
        cd ../
        git add Airplane
    )
fi

airplaneVer=$(gethead Airplane)
cd "$basedir/Airplane/"

./airplane p 2>&1 > /dev/null || exit 1

cd "Airplane-Server"
mcVer=$(mvn -o org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate -Dexpression=minecraft_version | sed -n -e '/^\[.*\]/ !{ /^[0-9]/ { p; q } }')

basedir
. "$basedir"/scripts/importmcdev.sh

minecraftversion=$(cat "$basedir"/Airplane/Tuinity/Paper/work/BuildData/info.json | grep minecraftVersion | cut -d '"' -f 4)
version=$(echo -e "Airplane: $airplaneVer\nmc-dev:$importedmcdev")
tag="${minecraftversion}-${mcVer}-$(echo -e $version | shasum | awk '{print $1}')"
echo "$tag" > "$basedir"/current-airplane

"$basedir"/scripts/generatesources.sh

cd Airplane/

function tag {
(
    cd $1
    if [ "$2" == "1" ]; then
        git tag -d "$tag" 2>/dev/null
    fi
    echo -e "$(date)\n\n$version" | git tag -a "$tag" -F - 2>/dev/null
)
}
echo "Tagging as $tag"
echo -e "$version"

forcetag=0
if [ "$(cat "$basedir"/current-airplane)" != "$tag" ]; then
    forcetag=1
fi

cd Tuinity/Paper/Paper-MojangAPI
git init
git add -A
git commit -m "Paper" --author="Paper <auto@mated.null>"

cd ../../..

tag Airplane-API $forcetag
tag Tuinity/Paper/Paper-MojangAPI $forcetag
tag Airplane-Server $forcetag

pushRepo Airplane-API $AIRPLANE_API_REPO $tag
pushRepo Tuinity/Paper/Paper-MojangAPI $PAPER_MOJANGAPI_REPO $tag
pushRepo Airplane-Server $AIRPLANE_SERVER_REPO $tag

