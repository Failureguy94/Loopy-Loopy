# 🚀 Reactive Looper - Quick Start

## Problem: CORS Error ❌

The frontend can't load ethers.js from CDN when opened directly (`file:///`) due to browser security (CORS policy).

## Solution: Use Local Server ✅

### Option 1: Double-Click START_SERVER.bat (Easiest!)

1. Go to: `C:\Users\kishlay kumar\Downloads\Loopy-Loopy\Loopy-Loopy\frontend\`
2. **Double-click** `START_SERVER.bat`
3. Browser will open automatically at `http://localhost:8000/standalone.html`
4. Done! 🎉

### Option 2: Manual Python Server

Open Command Prompt and run:
```cmd
cd "C:\Users\kishlay kumar\Downloads\Loopy-Loopy\Loopy-Loopy\frontend"
python -m http.server 8000
```

Then open browser to: `http://localhost:8000/standalone.html`

### Option 3: Node.js (if Python doesn't work)

```cmd
cd "C:\Users\kishlay kumar\Downloads\Loopy-Loopy\Loopy-Loopy\frontend"
npx serve -p 8000
```

Then open: `http://localhost:8000/standalone.html`

---

## Why This Happens

- **CORS** (Cross-Origin Resource Sharing) is a browser security feature
- Blocks loading external scripts when opening local files
- HTTP server solves this by serving files over `http://` instead of `file://`

## Features

✅ Connect MetaMask wallet
✅ Deposit ETH to start leverage looping
✅ View real-time position stats (LTV, Health Factor)
✅ Safe unwind position
✅ Activity log
✅ Dark blue theme

---

**Contract Address:** `0x10bA2B80361C686340ec09A04ee0BA4893531B9E` (Sepolia)
