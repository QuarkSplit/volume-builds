"""Run the shipped CPU voice workers in clean environments, with a public test sentence."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import wave

resources = Path(sys.argv[1])
work = Path(os.environ["RUNNER_TEMP"]) / "voice-check"
work.mkdir()
uv = resources / "runtime-bin/uv"
env = os.environ | {"HF_HOME": str(work / "hf"), "VIVAVOCE_DEFER_LOAD": "1", "OMP_NUM_THREADS": "2", "MKL_NUM_THREADS": "2"}
env.pop("HF_HUB_OFFLINE", None)
env.pop("TRANSFORMERS_OFFLINE", None)

def request(port, route, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(f"http://127.0.0.1:{port}/{route}", data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as response:
        return json.load(response)

for index, (engine, voice) in enumerate([("phonon", "freya"), ("kokoro", "bf_emma")]):
    source = resources / "runtime/workers" / engine
    project = work / engine
    project.mkdir()
    text = (source / "pyproject.toml").read_text().replace("https://download.pytorch.org/whl/cu130", "https://pypi.org/simple")
    (project / "pyproject.toml").write_text(text)
    if (source / "shims").exists():
        shutil.copytree(source / "shims", project / "shims")
    subprocess.run([str(uv), "sync", "--project", str(project), "--no-install-project", "--python", "3.12", "--managed-python"], env=env, check=True)
    port = 18761 + index
    worker = subprocess.Popen([str(project / ".venv/bin/python"), str(source / "worker.py"), "--port", str(port)], env=env)
    try:
        for attempt in range(120):
            if worker.poll() is not None:
                raise RuntimeError(f"{engine} exited during import")
            try:
                if request(port, "health").get("imported"):
                    break
            except urllib.error.URLError:
                time.sleep(1)
        else:
            raise RuntimeError(f"{engine} did not become ready")
        assert request(port, "load", {}).get("ok")
        output = work / f"{engine}.wav"
        result = request(port, "synth", {"text": "A quiet room can hold a great many books.", "voice": voice, "speed": 1.0, "out_path": str(output)})
        with wave.open(str(output)) as audio:
            duration = audio.getnframes() / audio.getframerate()
        assert duration > 1 and result["duration"] > 1
        print(f"Packaged {engine} speech passed: {duration:.2f} seconds")
    finally:
        worker.terminate()
        try:
            worker.wait(timeout=10)
        except subprocess.TimeoutExpired:
            worker.kill()
