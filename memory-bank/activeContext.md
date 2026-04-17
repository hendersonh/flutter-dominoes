# Active Context

## Current Objective
Ensure the production environment (https://hendy-dominoes.pages.dev) is updated correctly so the "refresh banner" (Update Notice) appears for users.

## Recent Changes
- **Deployment Rectification**: Discovered that previous deployments from the `feature/partners` branch were creating preview deployments instead of updating the production environment.
- **Production Build**: Regenerated `version.json` (1776433489841) and rebuilt the WASM binary.
- **Production Deploy**: Executed `npx wrangler pages deploy build/web --branch main` to specifically target the production environment.
- **Verification**: Confirmed via URL check that `https://hendy-dominoes.pages.dev/version.json` now returns the latest version ID.

## Next Steps
- [ ] Confirm with the user that the refresh banner is now appearing on their mobile device.
- [ ] Monitor the application for any other reported mobile UI/UX issues.

## Active Risks/Assumptions
- **Assumption**: The user is accessing `https://hendy-dominoes.pages.dev` directly.
- **Risk**: Aggressive browser caching or Service Worker persistence might delay the appearance of the banner even with the cache-buster, though the `version.json` fetch should work.
