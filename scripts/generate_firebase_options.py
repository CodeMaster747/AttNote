"""Generate lib/firebase_options.dart from firebase-config.json.

Used by the deploy workflows after running:
    firebase apps:sdkconfig WEB --project=<id> > firebase-config.json
"""

import json
import sys
from pathlib import Path


def main() -> int:
    config_path = Path("firebase-config.json")
    if not config_path.exists():
        print(f"error: {config_path} not found", file=sys.stderr)
        return 1

    raw = config_path.read_text()
    print(f"--- firebase-config.json ({len(raw)} bytes) ---")
    print(raw[:2000])
    print("--- end ---")

    # `firebase apps:sdkconfig WEB` may emit a JS snippet
    # (`firebase.initializeApp({...});`) instead of pure JSON.
    # Extract the object literal in that case.
    try:
        config = json.loads(raw)
    except json.JSONDecodeError:
        import re
        match = re.search(r"\{[\s\S]*\}", raw)
        if not match:
            print("error: no JSON object found in firebase-config.json", file=sys.stderr)
            return 1
        config = json.loads(match.group(0))

    api_key = config.get("apiKey", "")
    app_id = config.get("appId", "")
    messaging_sender_id = config.get("messagingSenderId", "")
    project_id = config.get("projectId", "")
    auth_domain = config.get("authDomain", "")
    storage_bucket = config.get("storageBucket", "")
    measurement_id = config.get("measurementId", "")

    dart_code = f"""// File generated for Firebase project: {project_id}
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform {{
    if (kIsWeb) {{
      return web;
    }}
    switch (defaultTargetPlatform) {{
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }}
  }}

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '{api_key}',
    appId: '{app_id}',
    messagingSenderId: '{messaging_sender_id}',
    projectId: '{project_id}',
    authDomain: '{auth_domain}',
    storageBucket: '{storage_bucket}',"""

    if measurement_id:
        dart_code += f"\n    measurementId: '{measurement_id}',"

    dart_code += """
  );
}
"""

    out = Path("lib/firebase_options.dart")
    out.write_text(dart_code)
    print(f"Generated {out} for project {project_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
