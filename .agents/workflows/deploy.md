---
description: Rebuild and deploy the Flutter WASM app to Cloudflare (PRODUCTION)
---
// turbo-all
1. **Confirm Target**: STOP and verify with the user: "Deploying to PRODUCTION (main branch). Proceed?"
2. Generate the version identifier: `powershell -ExecutionPolicy Bypass -File version_gen.ps1` in `flutter_app/`
3. Build the WASM binary: `flutter build web --wasm` in `flutter_app/`
4. Deploy to Cloudflare (Production): `npx wrangler pages deploy build/web --project-name hendy-dominoes --branch main` in `flutter_app/`
