#!/usr/bin/env python3
"""
Mooziac macOS App Complete Performance Benchmark Suite
Measures:
1. App Startup RAM & CPU
2. Idle RAM & CPU (Stabilized over minutes)
3. RAM While Playing Music
4. CPU While Idle
5. CPU While Playing Music
6. CPU When Minimized / Background
7. Number of Processes (Main App + Helpers)
8. WebView / WebKit Process Usage Breakdown
"""

import os
import sys
import time
import json
import statistics
import subprocess
from datetime import datetime

APP_PATH = "/Users/harshshirke/Applications/Mooziac.app"
LOG_DIR = "/Users/harshshirke/local/projects/Mooziac/mp3kal/scripts"

def run_cmd(cmd, check=True):
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=isinstance(cmd, str))
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\nStderr: {res.stderr}")
    return res.stdout.strip()

def kill_all_mooziac():
    print("[+] Ensuring clean slate (terminating existing Mooziac & WebKit processes)...")
    subprocess.run(["killall", "Mooziac"], stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-9", "-f", "Mooziac"], stderr=subprocess.DEVNULL)
    time.sleep(2)

def find_mooziac_pids():
    """
    Finds Mooziac main process and associated WebKit helper processes.
    """
    pids = {}
    # 1. Mooziac main
    try:
        out = run_cmd(["pgrep", "-x", "Mooziac"], check=False)
        for line in out.splitlines():
            if line.strip():
                pids[int(line.strip())] = "Mooziac (Main App)"
    except Exception:
        pass

    # 2. WebKit helpers
    try:
        out = run_cmd(["pgrep", "-f", "com.apple.WebKit"], check=False)
        for line in out.splitlines():
            if not line.strip():
                continue
            pid = int(line.strip())
            try:
                # Check command name
                cmd_out = run_cmd(["ps", "-p", str(pid), "-o", "command="], check=False)
                # Check open files for app.mooziac.mac
                lsof_out = run_cmd(f"lsof -p {pid} 2>/dev/null", check=False)
                is_mooziac = ("app.mooziac.mac" in lsof_out) or ("Mooziac" in lsof_out)
                
                # If there are no other WebKit consumers on system, check creation time or fallback
                if "WebContent" in cmd_out:
                    pids[pid] = "WebKit.WebContent (Rendering & JS)"
                elif "Networking" in cmd_out:
                    pids[pid] = "WebKit.Networking (Network & Cache)"
                elif "GPU" in cmd_out:
                    pids[pid] = "WebKit.GPU (Metal & Media Codecs)"
                else:
                    pids[pid] = f"WebKit.Helper ({pid})"
            except Exception:
                pass
    except Exception:
        pass

    return pids

def sample_process_metrics(pids):
    """
    Samples CPU% and RSS (MB) for given PIDs using ps.
    Returns: {pid: {'name': str, 'cpu': float, 'rss_mb': float}}
    """
    if not pids:
        return {}
    pid_list = [str(p) for p in pids.keys()]
    try:
        cmd = ["ps", "-p", ",".join(pid_list), "-o", "pid=,%cpu=,rss="]
        out = run_cmd(cmd, check=False)
        results = {}
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 3:
                pid = int(parts[0])
                cpu = float(parts[1])
                rss_kb = float(parts[2])
                name = pids.get(pid, f"Process-{pid}")
                results[pid] = {
                    "name": name,
                    "cpu": cpu,
                    "rss_mb": round(rss_kb / 1024.0, 2)
                }
        return results
    except Exception as e:
        return {}

def sample_footprint(pids):
    """
    Uses macOS `footprint` tool to measure exact physical dirty memory.
    """
    if not pids:
        return {}, 0.0
    pid_list = [str(p) for p in pids.keys()]
    try:
        cmd = ["footprint", "-p"] + pid_list
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        out = res.stdout
        per_pid_fp = {}
        total_fp = 0.0
        
        # Parse Summary Footprint
        for line in out.splitlines():
            if "Summary Footprint:" in line:
                # e.g., Summary Footprint: 298 MB
                parts = line.split("Summary Footprint:")
                if len(parts) > 1:
                    val_str = parts[1].strip()
                    if "MB" in val_str:
                        total_fp = float(val_str.replace("MB", "").strip())
                    elif "GB" in val_str:
                        total_fp = float(val_str.replace("GB", "").strip()) * 1024.0
                    elif "KB" in val_str:
                        total_fp = float(val_str.replace("KB", "").strip()) / 1024.0
            
            # Parse individual process footprints
            for pid in pids:
                if f"[{pid}]:" in line and "Footprint:" in line:
                    # e.g. Mooziac [5974]: 64-bit    Footprint: 62 MB
                    fp_part = line.split("Footprint:")[1].strip().split()[0]
                    unit = line.split("Footprint:")[1].strip().split()[1] if len(line.split("Footprint:")[1].strip().split()) > 1 else "MB"
                    val = float(fp_part)
                    if unit == "KB":
                        val = val / 1024.0
                    elif unit == "GB":
                        val = val * 1024.0
                    per_pid_fp[pid] = round(val, 2)
        
        return per_pid_fp, total_fp
    except Exception:
        return {}, 0.0

def toggle_playback_hotkey():
    """Triggers Cmd+Shift+Space to toggle play/pause"""
    cmd = """osascript -e 'tell application "System Events" to key code 49 using {command down, shift down}'"""
    subprocess.run(cmd, shell=True, stderr=subprocess.DEVNULL)

def click_status_item():
    """Clicks Mooziac status bar item to minimize/restore panel"""
    cmd = """osascript -e 'tell application "System Events" to tell process "Mooziac" to click menu bar item 1 of menu bar 2'"""
    subprocess.run(cmd, shell=True, stderr=subprocess.DEVNULL)

def record_phase(phase_name, duration_seconds, sample_interval=2.0, action_hook=None):
    print(f"\n--- Starting Phase: {phase_name} ({duration_seconds}s) ---")
    if action_hook:
        action_hook()
    
    samples = []
    start_time = time.time()
    while time.time() - start_time < duration_seconds:
        t_elapsed = round(time.time() - start_time, 2)
        pids = find_mooziac_pids()
        metrics = sample_process_metrics(pids)
        
        total_cpu = sum(m["cpu"] for m in metrics.values())
        total_rss = sum(m["rss_mb"] for m in metrics.values())
        
        sample_entry = {
            "elapsed_s": t_elapsed,
            "timestamp": datetime.now().isoformat(),
            "process_count": len(pids),
            "total_cpu": round(total_cpu, 2),
            "total_rss_mb": round(total_rss, 2),
            "processes": metrics
        }
        samples.append(sample_entry)
        
        print(f"[{phase_name}] t={t_elapsed:5.1f}s | Procs={len(pids)} | Total CPU={total_cpu:5.1f}% | Total RSS={total_rss:6.1f} MB")
        for pid, pdata in metrics.items():
            print(f"    ↳ PID {pid:5d} [{pdata['name']:32s}]: CPU={pdata['cpu']:4.1f}% | RSS={pdata['rss_mb']:6.1f} MB")
        
        time.sleep(sample_interval)
    
    # Take a detailed footprint reading at the end of the phase
    final_pids = find_mooziac_pids()
    per_pid_fp, summary_fp = sample_footprint(final_pids)
    
    # Calculate statistics
    cpu_vals = [s["total_cpu"] for s in samples] if samples else [0.0]
    rss_vals = [s["total_rss_mb"] for s in samples] if samples else [0.0]
    
    phase_summary = {
        "phase_name": phase_name,
        "duration_seconds": duration_seconds,
        "sample_count": len(samples),
        "process_count": len(final_pids),
        "cpu_stats": {
            "min": round(min(cpu_vals), 2),
            "max": round(max(cpu_vals), 2),
            "mean": round(statistics.mean(cpu_vals), 2),
            "median": round(statistics.median(cpu_vals), 2),
            "stdev": round(statistics.stdev(cpu_vals), 2) if len(cpu_vals) > 1 else 0.0
        },
        "rss_mb_stats": {
            "min": round(min(rss_vals), 2),
            "max": round(max(rss_vals), 2),
            "mean": round(statistics.mean(rss_vals), 2),
            "median": round(statistics.median(rss_vals), 2),
            "final": round(rss_vals[-1], 2) if rss_vals else 0.0
        },
        "footprint_mb": {
            "per_pid": per_pid_fp,
            "summary_total": summary_fp
        },
        "samples": samples
    }
    return phase_summary

def main():
    print("=" * 70)
    print(" 🚀 MOOZIAC FULL PERFORMANCE BENCHMARK SUITE")
    print("    Environment: macOS Apple Silicon / macOS Sonoma/Sequoia")
    print(f"    Date/Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    all_results = {}

    # STEP 1: Cold Startup
    kill_all_mooziac()
    print("\n[Phase 1] Launching fresh instance of Mooziac...")
    launch_start = time.time()
    subprocess.Popen(["open", APP_PATH])
    
    # Measure immediately during startup (first 6 seconds, 1s interval)
    phase1_startup = record_phase("1. Cold App Startup", duration_seconds=6, sample_interval=1.0)
    all_results["startup"] = phase1_startup

    # STEP 2: Idle Stabilization (90 seconds to allow WebKit + AppKit to fully settle)
    print("\n[Phase 2] Allowing app to stabilize in Idle state for 90 seconds...")
    phase2_idle = record_phase("2. Stabilized Idle", duration_seconds=90, sample_interval=3.0)
    all_results["idle"] = phase2_idle

    # STEP 3: Active Music Playback (Continuous playback for 90 seconds)
    print("\n[Phase 3] Starting continuous music playback via global hotkey...")
    def start_playback():
        toggle_playback_hotkey()
        time.sleep(2)
    phase3_playback = record_phase("3. Active Music Playback", duration_seconds=90, sample_interval=3.0, action_hook=start_playback)
    all_results["playback"] = phase3_playback

    # STEP 4: Minimized / Background State (Continuous playback in background / minimized for 45s)
    print("\n[Phase 4] Testing Minimized / Background state...")
    def minimize_app():
        click_status_item()
        time.sleep(1)
    phase4_minimized = record_phase("4. Background / Minimized Playback", duration_seconds=45, sample_interval=3.0, action_hook=minimize_app)
    all_results["minimized"] = phase4_minimized

    # STEP 5: Pause & Post-Playback Idle / Leak Check (45 seconds)
    print("\n[Phase 5] Pausing music and measuring memory release & recovery...")
    def pause_music():
        toggle_playback_hotkey()
        time.sleep(1)
    phase5_post_idle = record_phase("5. Post-Playback Idle & Recovery", duration_seconds=45, sample_interval=3.0, action_hook=pause_music)
    all_results["post_playback_idle"] = phase5_post_idle

    # Save complete JSON logs
    json_path = os.path.join(LOG_DIR, "performance_results.json")
    with open(json_path, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\n[✓] Performance benchmark complete. Raw logs saved to: {json_path}")

if __name__ == "__main__":
    main()
