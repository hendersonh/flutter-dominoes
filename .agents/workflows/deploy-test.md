---
description: Rebuild and deploy the Flutter WASM app to the Cloudflare (TESTING)
---
// turbo-all
1. **Confirm Target**: STOP and verify with the user: "Deploying to TESTING (test branch). Proceed?"
2. Generate the version identifier: `powershell -ExecutionPolicy Bypass -File version_gen.ps1` in `flutter_app/`
3. Build the WASM binary: `flutter build web --wasm` in `flutter_app/`
4. Deploy to Cloudflare (Test): `npx wrangler pages deploy build/web --project-name hendy-dominoes --branch test` in `flutter_app/`
