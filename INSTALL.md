# Install Culture on your iPhone and iPad

You need: a **Mac**, a **USB cable** for each device, and an **Apple ID** (a free one works).

## 1. One-time setup on the Mac

1. Install **Xcode** from the Mac App Store (free, large download) and open it once to finish installing components.
2. In Xcode: **Xcode ▸ Settings… ▸ Accounts ▸ +** and sign in with your Apple ID.

## 2. Get the project

1. On https://github.com/geigecoast/culture click **Code ▸ Download ZIP**.
2. Double-click the ZIP in Downloads to unzip it.
3. Double-click **`Culture.xcodeproj`** inside the folder. Xcode opens the project.

## 3. Sign the app (first time only)

1. In Xcode's left panel click the blue **Culture** project icon at the top.
2. Under **TARGETS**, select **Culture**, open **Signing & Capabilities**, tick **Automatically manage signing** and pick your name under **Team** ("Personal Team").
3. Do the same for the **CultureWidgets** target.
4. If Xcode says the bundle identifier is not available, change `com.geigecoast.culture` to something unique such as `com.yourname.culture` (and `…culture.widgets` for the widget).

## 4. Install on the iPhone (then the same for the iPad)

1. Plug the iPhone into the Mac, unlock it and tap **Trust This Computer**.
2. On the iPhone: **Settings ▸ Privacy & Security ▸ Developer Mode ▸ On** (the phone restarts; confirm after the restart). This option appears only after the phone has been connected to Xcode once.
3. In Xcode's top bar, choose your iPhone as the run destination (next to the ▶ button).
4. Press **▶ Run** (or ⌘R). The first build takes a few minutes.
5. The first time, the iPhone says the developer is not trusted: go to **Settings ▸ General ▸ VPN & Device Management**, tap your Apple ID, then **Trust**. Open Culture again.

Repeat step 4 with the iPad plugged in.

## Good to know

- **Free Apple ID:** the app keeps working for **7 days**, then needs reinstalling (plug in, press ▶ again). Your progress stays on the device.
- **Paid Apple Developer Program (99 $/year):** no 7-day limit, and you can use **TestFlight** to install over the air on any device without a cable. To enable Sign in with Apple, widgets data sharing and push, generate the project from `project-paid.yml` (see README).
- Content currently shown is marked **"En relecture"** (not yet reviewed by experts) and events are **examples**: see `docs/CONTENT_REVIEW_REPORT.md`.
