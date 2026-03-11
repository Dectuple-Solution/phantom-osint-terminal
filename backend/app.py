from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import subprocess, threading, uuid, json, re, os, csv, io
from datetime import datetime

app = Flask(__name__)
CORS(app)

jobs = {}

def run_command(cmd, timeout=60):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT: Command took too long"
    except Exception as e:
        return f"ERROR: {str(e)}"

def check_tool_installed(tool):
    result = subprocess.run(f"which {tool}", shell=True, capture_output=True, text=True)
    return result.returncode == 0

# ─────────────────────────────────────────
#  EMAIL INVESTIGATION
# ─────────────────────────────────────────
def investigate_email(email, job_id):
    results = {}

    jobs[job_id]["status"] = "Running holehe (checking 120+ platforms)..."
    if check_tool_installed("holehe"):
        out = run_command(f"holehe {email} --no-color 2>&1", timeout=90)
        found, not_found = [], []
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("[+]"):   found.append(line.replace("[+]","").strip())
            elif line.startswith("[-]"): not_found.append(line.replace("[-]","").strip())
        results["holehe"] = {"found": found, "not_found": not_found, "raw": out[:3000]}
    else:
        results["holehe"] = {"error": "holehe not installed"}

    jobs[job_id]["status"] = "Running h8mail (breach check)..."
    if check_tool_installed("h8mail"):
        out = run_command(f"h8mail -t {email} 2>&1", timeout=60)
        breaches = [l.strip() for l in out.splitlines()
                    if any(w in l.lower() for w in ["breach","leak","found","pwned"])]
        results["h8mail"] = {"breaches": breaches, "raw": out[:3000]}
    else:
        results["h8mail"] = {"error": "h8mail not installed"}

    jobs[job_id]["status"] = "Running theHarvester (domain recon)..."
    domain = email.split("@")[-1] if "@" in email else email
    if check_tool_installed("theHarvester"):
        out = run_command(f"theHarvester -d {domain} -b google,bing,duckduckgo -l 50 2>&1", timeout=90)
        emails_found = list(set(re.findall(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}', out)))
        results["theHarvester"] = {"emails": emails_found, "raw": out[:3000]}
    else:
        results["theHarvester"] = {"error": "theHarvester not installed"}

    jobs[job_id].update({"results": results, "status": "complete", "type": "email", "target": email})

# ─────────────────────────────────────────
#  PHONE INVESTIGATION
# ─────────────────────────────────────────
def investigate_phone(phone, job_id):
    results = {}

    jobs[job_id]["status"] = "Running PhoneInfoga..."
    if check_tool_installed("phoneinfoga"):
        out = run_command(f"phoneinfoga scan -n {phone} 2>&1", timeout=60)
        info = {}
        for line in out.splitlines():
            for key in ["Country","Carrier","carrier","Line type","line_type","Local","International","Valid"]:
                if key in line and ":" in line:
                    info[key.lower().replace(" ","_")] = line.split(":",1)[-1].strip()
        results["phoneinfoga"] = {"info": info, "raw": out[:3000]}
    else:
        results["phoneinfoga"] = {"error": "phoneinfoga not installed — run install_tools.sh"}

    jobs[job_id]["status"] = "Analyzing number format..."
    clean = re.sub(r'[^\d+]', '', phone)
    country_map = {'+92':'Pakistan','+1':'USA/Canada','+44':'UK','+91':'India',
                   '+49':'Germany','+33':'France','+86':'China','+81':'Japan',
                   '+971':'UAE','+966':'Saudi Arabia','+880':'Bangladesh'}
    country = next((v for k,v in country_map.items() if clean.startswith(k)), "Unknown")
    results["number_analysis"] = {
        "input": phone, "cleaned": clean,
        "digit_count": len(clean.replace('+','')),
        "has_country_code": clean.startswith('+'),
        "country": country
    }

    jobs[job_id].update({"results": results, "status": "complete", "type": "phone", "target": phone})

# ─────────────────────────────────────────
#  USERNAME INVESTIGATION
# ─────────────────────────────────────────
def investigate_username(username, job_id):
    results = {}

    jobs[job_id]["status"] = "Running Sherlock (400+ sites)..."
    sherlock_path = os.path.expanduser("~/sherlock/sherlock.py")
    if os.path.exists(sherlock_path):
        out = run_command(f"python3 {sherlock_path} {username} --print-found --no-color 2>&1", timeout=120)
        found = [l.replace("[+]","").strip() for l in out.splitlines() if l.startswith("[+]")]
        results["sherlock"] = {"found": found, "count": len(found), "raw": out[:4000]}
    else:
        results["sherlock"] = {"error": "Sherlock not found — run install_tools.sh"}

    jobs[job_id]["status"] = "Running Maigret (2500+ sites)..."
    if check_tool_installed("maigret"):
        out = run_command(f"maigret {username} --no-color 2>&1", timeout=180)
        found = [l.strip() for l in out.splitlines() if "[+]" in l]
        results["maigret"] = {"found": found, "count": len(found), "raw": out[:4000]}
    else:
        results["maigret"] = {"error": "maigret not installed — run install_tools.sh"}

    jobs[job_id].update({"results": results, "status": "complete", "type": "username", "target": username})

# ─────────────────────────────────────────
#  ROUTES
# ─────────────────────────────────────────
@app.route('/api/scan', methods=['POST'])
def start_scan():
    data = request.json
    scan_type = data.get('type')
    target = data.get('target','').strip()
    if not target:
        return jsonify({"error": "No target provided"}), 400

    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status":"starting","results":{},"type":scan_type,"target":target,
                    "timestamp": datetime.now().isoformat()}

    fn_map = {"email":investigate_email,"phone":investigate_phone,"username":investigate_username}
    fn = fn_map.get(scan_type)
    if not fn:
        return jsonify({"error": "Invalid type"}), 400

    t = threading.Thread(target=fn, args=(target, job_id))
    t.daemon = True
    t.start()
    return jsonify({"job_id": job_id})

@app.route('/api/status/<job_id>', methods=['GET'])
def get_status(job_id):
    if job_id not in jobs:
        return jsonify({"error": "Job not found"}), 404
    job = jobs[job_id]
    return jsonify({
        "status": job["status"],
        "type": job.get("type"),
        "target": job.get("target"),
        "timestamp": job.get("timestamp"),
        "results": job.get("results",{}) if job["status"]=="complete" else {}
    })

@app.route('/api/tools', methods=['GET'])
def check_tools():
    return jsonify({
        "holehe":       check_tool_installed("holehe"),
        "h8mail":       check_tool_installed("h8mail"),
        "theHarvester": check_tool_installed("theHarvester"),
        "phoneinfoga":  check_tool_installed("phoneinfoga"),
        "sherlock":     os.path.exists(os.path.expanduser("~/sherlock/sherlock.py")),
        "maigret":      check_tool_installed("maigret"),
    })

# ─────────────────────────────────────────
#  EXPORT ROUTES
# ─────────────────────────────────────────
@app.route('/api/export/json/<job_id>', methods=['GET'])
def export_json(job_id):
    if job_id not in jobs or jobs[job_id]["status"] != "complete":
        return jsonify({"error": "Job not ready"}), 404
    job = jobs[job_id]
    export_data = {
        "phantom_version": "1.0.0",
        "export_time": datetime.now().isoformat(),
        "target": job.get("target"),
        "type": job.get("type"),
        "scan_time": job.get("timestamp"),
        "results": job.get("results", {})
    }
    buf = io.BytesIO(json.dumps(export_data, indent=2).encode())
    buf.seek(0)
    fname = f"phantom_{job['type']}_{job['target'].replace('@','_at_').replace('+','').replace(' ','_')}.json"
    return send_file(buf, mimetype='application/json',
                     as_attachment=True, download_name=fname)

@app.route('/api/export/csv/<job_id>', methods=['GET'])
def export_csv(job_id):
    if job_id not in jobs or jobs[job_id]["status"] != "complete":
        return jsonify({"error": "Job not ready"}), 404
    job = jobs[job_id]
    r = job.get("results", {})
    scan_type = job.get("type")
    target = job.get("target","")

    output = io.StringIO()
    writer = csv.writer(output)

    writer.writerow(["PHANTOM OSINT Terminal Report"])
    writer.writerow(["Target", target])
    writer.writerow(["Type", scan_type])
    writer.writerow(["Scan Time", job.get("timestamp","")])
    writer.writerow(["Export Time", datetime.now().isoformat()])
    writer.writerow([])

    if scan_type == "email":
        if "holehe" in r and "found" in r["holehe"]:
            writer.writerow(["=== HOLEHE — Accounts Found ==="])
            writer.writerow(["Platform"])
            for item in r["holehe"].get("found",[]):
                writer.writerow([item])
            writer.writerow([])

        if "h8mail" in r and "breaches" in r["h8mail"]:
            writer.writerow(["=== H8MAIL — Data Breaches ==="])
            writer.writerow(["Breach Info"])
            for item in r["h8mail"].get("breaches",[]):
                writer.writerow([item])
            writer.writerow([])

        if "theHarvester" in r and "emails" in r["theHarvester"]:
            writer.writerow(["=== theHarvester — Related Emails ==="])
            writer.writerow(["Email"])
            for item in r["theHarvester"].get("emails",[]):
                writer.writerow([item])

    elif scan_type == "phone":
        writer.writerow(["=== Number Analysis ==="])
        writer.writerow(["Field","Value"])
        for k,v in r.get("number_analysis",{}).items():
            writer.writerow([k, v])
        writer.writerow([])
        writer.writerow(["=== PhoneInfoga Results ==="])
        writer.writerow(["Field","Value"])
        for k,v in r.get("phoneinfoga",{}).get("info",{}).items():
            writer.writerow([k, v])

    elif scan_type == "username":
        writer.writerow(["=== Sherlock — Found Profiles ==="])
        writer.writerow(["URL / Platform"])
        for item in r.get("sherlock",{}).get("found",[]):
            writer.writerow([item])
        writer.writerow([])
        writer.writerow(["=== Maigret — Found Profiles ==="])
        writer.writerow(["URL / Platform"])
        for item in r.get("maigret",{}).get("found",[]):
            writer.writerow([item])

    output.seek(0)
    buf = io.BytesIO(output.getvalue().encode())
    buf.seek(0)
    fname = f"phantom_{scan_type}_{target.replace('@','_at_').replace('+','').replace(' ','_')}.csv"
    return send_file(buf, mimetype='text/csv',
                     as_attachment=True, download_name=fname)

@app.route('/api/export/txt/<job_id>', methods=['GET'])
def export_txt(job_id):
    if job_id not in jobs or jobs[job_id]["status"] != "complete":
        return jsonify({"error": "Job not ready"}), 404
    job = jobs[job_id]
    r = job.get("results", {})
    scan_type = job.get("type")
    target = job.get("target","")

    lines = []
    lines.append("=" * 60)
    lines.append("  PHANTOM — OSINT Intelligence Terminal")
    lines.append("  https://github.com/Dectuple-Solution/phantom-osint-terminal")
    lines.append("=" * 60)
    lines.append(f"  Target    : {target}")
    lines.append(f"  Type      : {scan_type.upper()}")
    lines.append(f"  Scan Time : {job.get('timestamp','')}")
    lines.append(f"  Export    : {datetime.now().isoformat()}")
    lines.append("=" * 60)
    lines.append("")

    if scan_type == "email":
        h = r.get("holehe",{})
        found = h.get("found",[])
        lines.append(f"[HOLEHE] Accounts Found: {len(found)}")
        lines.append("-" * 40)
        for f in found: lines.append(f"  [+] {f}")
        lines.append("")

        br = r.get("h8mail",{}).get("breaches",[])
        lines.append(f"[H8MAIL] Data Breaches: {len(br)}")
        lines.append("-" * 40)
        for b in br: lines.append(f"  [!] {b}")
        lines.append("")

        em = r.get("theHarvester",{}).get("emails",[])
        lines.append(f"[theHarvester] Related Emails: {len(em)}")
        lines.append("-" * 40)
        for e in em: lines.append(f"  [@] {e}")

    elif scan_type == "phone":
        lines.append("[NUMBER ANALYSIS]")
        lines.append("-" * 40)
        for k,v in r.get("number_analysis",{}).items():
            lines.append(f"  {k:<20} : {v}")
        lines.append("")
        lines.append("[PHONEINFOGA]")
        lines.append("-" * 40)
        for k,v in r.get("phoneinfoga",{}).get("info",{}).items():
            lines.append(f"  {k:<20} : {v}")

    elif scan_type == "username":
        sh = r.get("sherlock",{}).get("found",[])
        lines.append(f"[SHERLOCK] Found on {len(sh)} platforms")
        lines.append("-" * 40)
        for s in sh: lines.append(f"  [+] {s}")
        lines.append("")
        mg = r.get("maigret",{}).get("found",[])
        lines.append(f"[MAIGRET] Found on {len(mg)} platforms")
        lines.append("-" * 40)
        for m in mg: lines.append(f"  [+] {m}")

    lines.append("")
    lines.append("=" * 60)
    lines.append("  Generated by PHANTOM OSINT Terminal — For authorized use only")
    lines.append("=" * 60)

    content = "\n".join(lines)
    buf = io.BytesIO(content.encode())
    buf.seek(0)
    fname = f"phantom_{scan_type}_{target.replace('@','_at_').replace('+','').replace(' ','_')}.txt"
    return send_file(buf, mimetype='text/plain',
                     as_attachment=True, download_name=fname)

if __name__ == '__main__':
    print("\n  PHANTOM Backend running at http://localhost:5000")
    print("  Open frontend/index.html in your browser\n")
    app.run(host='0.0.0.0', port=5000, debug=False)