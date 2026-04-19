# Google Play Store Dossier: HendyDominoes

Use this document as your primary "Copy-Paste" source while navigating the Google Play Console setup forms.

---

## 1. App Identifiers
*   **App Name**: HendyDominoes
*   **Package Name**: `com.hoodhlab.dominoes`
*   **App Type**: Game
*   **Category**: Games > Board
*   **Price**: Free

---

## 2. Store Listing Content

### Short Description (80 characters max)
High-fidelity Caribbean Dominoes. Legend-tier AI, Six-Love rules, and WASM speed.

### Full Description
Master the board with HendyDominoes! Experience the definitive Cut-Throat and Six-Love dominoes simulation, built for players who demand strategy and style.

**Key Features:**
- **Advanced AI**: Face off against our search-based AI with 4 difficulty levels: Rookie, Casual, Professional, and the unforgiving Legend mode.
- **Traditional Scoring**: Full support for Six-Love championship rules, including the "Key Bone" bonus and Game Bruk logic.
- **Premium Design**: A stunning interactive board with smooth animations, haptic feedback, and a sleek dark-mode aesthetic.
- **Offline First**: No internet required. Play anytime, anywhere.
- **Privacy Design**: No data collection. Your stats and settings stay on your device.

---

## 3. Mandatory Setup Tasks (The "Checklist")

Navigate to **Dashboard** > **Set up your app**. Complete these in order:

### 1. Set Privacy Policy
*   **URL**: `https://hendy-dominoes.pages.dev/privacy.html`
    *   *(Note: This URL is automatically live once I deploy your web version next).*

### 2. App Access
*   **Option**: "All functionality is available without special access" (since there is no login required).

### 3. Ads
*   **Option**: "No, my app does not contain ads."

### 4. Content Rating
*   **Start Questionnaire**:
    *   **Category**: Game
    *   **Violence/Fear/Sex**: No to all.
    *   **Gambling**: No (this is a strategy game, no real money).
    *   **User Contributed Content**: No.
    *   **Online**: No.

### 5. Target Audience
*   **Age**: Select **13-15**, **16-17**, and **18 and over**.
*   **Unintentional Appeal to Children**: No.

### 6. Data Safety (IMPORTANT)
*   **Does your app collect or share any of the required user data types?**: **No**.
*   **Is all of the user data collected by your app encrypted in transit?**: **N/A** (No data collected).
*   **Do you provide a way for users to request that their data is deleted?**: **Yes** (Since all data is local, inform them that deleting the app deletes all data).

---

## 4. Graphics Check
*   **App Icon**: Use `flutter_app/assets/app-icon.png` (512x512 required).
*   **Feature Graphic**: 1024x500 (I will generate this for you if needed).
*   **Screenshots**: 2-8 required. I will provide a method to capture these later.
