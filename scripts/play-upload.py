#!/usr/bin/env python3
"""Upload an Android App Bundle to a Google Play track.

    scripts/play-upload.py <service-account.json> <package> <bundle.aab> [track]

The track defaults to "internal". Only the standard library and openssl are
used, so nothing needs installing. The service account needs "Release apps to
testing tracks" on the app in Play Console (Users and permissions).

An app that has never been rolled out anywhere is still a draft, and Play only
takes draft releases for it; the release then waits in Play Console for
"Review release" > "Start rollout". Once one has gone out, later uploads roll
out to the track's testers straight away.
"""

import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD_API = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token(account):
    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {
        "iss": account["client_email"],
        "scope": SCOPE,
        "aud": account["token_uri"],
        "iat": now,
        "exp": now + 3600,
    }
    signing_input = (
        b64url(json.dumps(header).encode()) + "." + b64url(json.dumps(claims).encode())
    )
    with tempfile.NamedTemporaryFile("w", suffix=".pem") as key:
        os.chmod(key.name, 0o600)
        key.write(account["private_key"])
        key.flush()
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key.name],
            input=signing_input.encode(),
            capture_output=True,
            check=True,
        ).stdout
    jwt = signing_input + "." + b64url(signature)
    body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + jwt
    response = request("POST", account["token_uri"], body.encode(),
                       {"Content-Type": "application/x-www-form-urlencoded"})
    return response["access_token"]


def request(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=600) as response:
            text = response.read().decode()
    except urllib.error.HTTPError as error:
        raise PlayError(error.code, error.read().decode()) from None
    return json.loads(text) if text else {}


class PlayError(Exception):
    def __init__(self, code, body):
        super().__init__("HTTP %d: %s" % (code, body))
        self.body = body


def main():
    if len(sys.argv) not in (4, 5):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    key_path, package, bundle = sys.argv[1:4]
    track = sys.argv[4] if len(sys.argv) == 5 else "internal"
    with open(key_path) as f:
        account = json.load(f)

    token = access_token(account)
    auth = {"Authorization": "Bearer " + token}
    json_auth = dict(auth, **{"Content-Type": "application/json"})
    app = "%s/%s" % (API, package)

    edit = request("POST", app + "/edits", b"{}", json_auth)["id"]
    print("Uploading %s" % os.path.basename(bundle))
    with open(bundle, "rb") as f:
        uploaded = request(
            "POST",
            "%s/%s/edits/%s/bundles?uploadType=media" % (UPLOAD_API, package, edit),
            f.read(),
            dict(auth, **{"Content-Type": "application/octet-stream"}),
        )
    version_code = str(uploaded["versionCode"])

    def release(status):
        body = {"track": track, "releases": [{"versionCodes": [version_code], "status": status}]}
        request("PUT", "%s/edits/%s/tracks/%s" % (app, edit, track),
                json.dumps(body).encode(), json_auth)
        request("POST", "%s/edits/%s:commit" % (app, edit), b"", auth)

    try:
        release("completed")
        print("Version %s is out to the %s track's testers." % (version_code, track))
    except PlayError as error:
        if "draft app" not in error.body:
            raise
        release("draft")
        print("Version %s is a draft on the %s track: the app has never been rolled" % (version_code, track))
        print("out, so Play Console has to start this one (Testing > Internal testing).")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except PlayError as error:
        print("Play rejected the upload: %s" % error, file=sys.stderr)
        sys.exit(1)
