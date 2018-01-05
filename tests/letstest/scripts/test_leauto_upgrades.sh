#!/bin/bash -xe
set -o pipefail

# $OS_TYPE $PUBLIC_IP $PRIVATE_IP $PUBLIC_HOSTNAME $BOULDER_URL
# are dynamically set at execution

cd letsencrypt

EXPECTED_VERSION=$(grep -m1 LE_AUTO_VERSION letsencrypt-auto | cut -d\" -f2)
LE_AUTO_CONTENTS=$(cat letsencrypt-auto-source/letsencrypt-auto)
SIGNING_KEY="letsencrypt-auto-source/tests/signing.key"

if ! command -v git ; then
    if [ "$OS_TYPE" = "ubuntu" ] ; then
        sudo apt-get update
    fi
    if ! (  sudo apt-get install -y git || sudo yum install -y git-all || sudo yum install -y git || sudo dnf install -y git ) ; then
        echo git installation failed!
        exit 1
    fi
fi

# 0.5.0 is the oldest version of letsencrypt-auto that can be used because it's
# the first version that pins package versions, properly supports
# --no-self-upgrade, and works with newer versions of pip.
git checkout -f v0.5.0 letsencrypt-auto
if ! ./letsencrypt-auto -v --debug --version --no-self-upgrade 2>&1 | grep 0.5.0 ; then
    echo initial installation appeared to fail
    exit 1
fi

# Now that python and openssl have been installed, we can set up a fake server
# to provide a new version of letsencrypt-auto. First, we start the server and
# directory to be served.
MY_TEMP_DIR=$(mktemp -d)
SERVER_PY=$(tools/readlink.py tools/simple_https_server.py)
SERVER_OUT="$MY_TEMP_DIR/port"
cd "$MY_TEMP_DIR"
openssl req -new -x509 -keyout server.pem -out server.pem -days 365 -nodes
"$SERVER_PY" > "$SERVER_OUT" 2>&1 &
SERVER_PID=$!
cd ~-
trap 'kill "$SERVER_PID" && rm -rf "$MY_TEMP_DIR"' EXIT

# Next, we set up the files to be served.
FAKE_VERSION_NUM="99.99.99"
mkdir "$MY_TEMP_DIR/certbot"
echo "{\"releases\": {\"$FAKE_VERSION_NUM\": null}}" > "$MY_TEMP_DIR/certbot/json"
LE_AUTO_SOURCE_DIR="$MY_TEMP_DIR/v$FAKE_VERSION_NUM"
NEW_LE_AUTO_PATH="$LE_AUTO_SOURCE_DIR/letsencrypt-auto"
mkdir "$LE_AUTO_SOURCE_DIR"
echo "$LE_AUTO_CONTENTS" > "$LE_AUTO_SOURCE_DIR/letsencrypt-auto"
openssl dgst -sha256 -sign "$SIGNING_KEY" -out "$NEW_LE_AUTO_PATH.sig" "$NEW_LE_AUTO_PATH"

# Finally, we set the necessary certbot-auto environment variables.
export LE_AUTO_DIR_TEMPLATE="https://localhost:$SERVER_PORT/%s/"
export LE_AUTO_JSON_URL="https://localhost:$SERVER_PORT/certbot/json"
export LE_AUTO_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsMoSzLYQ7E1sdSOkwelg
tzKIh2qi3bpXuYtcfFC0XrvWig071NwIj+dZiT0OLZ2hPispEH0B7ISuuWg1ll7G
hFW0VdbxL6JdGzS2ShNWkX9hE9z+j8VqwDPOBn3ZHm03qwpYkBDwQib3KqOdYbTT
uUtJmmGcuk3a9Aq/sCT6DdfmTSdP5asdQYwIcaQreDrOosaS84DTWI3IU+UYJVgl
LsIVPBuy9IcgHidUQ96hJnoPsDCWsHwX62495QKEarauyKQrJzFes0EY95orDM47
Z5o/NDiQB11m91yNB0MmPYY9QSbnOA9j7IaaC97AwRLuwXY+/R2ablTcxurWou68
iQIDAQAB
-----END PUBLIC KEY-----
"
export NO_CERT_VERIFY=1

./letsencrypt-auto -v --debug --version > /dev/null 2>&1
if ! diff letsencrypt-auto "$NEW_LE_AUTO_PATH"; then
    echo upgrade appeared to fail
    exit 1
fi
echo upgrade appeared to be successful

if [ "$(tools/readlink.py ${XDG_DATA_HOME:-~/.local/share}/letsencrypt)" != "/opt/eff.org/certbot/venv" ]; then
    echo symlink from old venv path not properly created!
    exit 1
fi
echo symlink properly created
