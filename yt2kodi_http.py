from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

SCRIPT_PATH = "/path/to/your/bash/script.sh"  # Update this with the path to your script

@app.route('/api/get/<path:youtube_url>', methods=['GET'])
def trigger_script(youtube_url):
    try:
        # Run the script with the YouTube URL as an argument
        result = subprocess.run(
            [SCRIPT_PATH, youtube_url],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Check for script execution errors
        if result.returncode != 0:
            return jsonify({"status": "error", "message": result.stderr}), 400
        
        return jsonify({"status": "success", "message": result.stdout}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=6578)
