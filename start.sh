#!/bin/bash
echo ""
echo "  PHANTOM OSINT Terminal"
echo "  ────────────────────────────────────"
echo "  Backend  → http://localhost:5000"
echo "  Frontend → Open frontend/index.html"
echo ""
cd "$(dirname "$0")/backend"
python3 app.py
