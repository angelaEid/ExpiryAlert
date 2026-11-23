from flask import Flask
from dotenv import load_dotenv
import os

from routes.main import main_bp
from routes.inventory import inventory_bp
from routes.alerts import alerts_bp

# Load environment variables from .env
load_dotenv()

def create_app():
    app = Flask(__name__)

    # Enable Flask sessions and flash messages
    app.config["SECRET_KEY"] = os.environ["SECRET_KEY"]

    app.register_blueprint(main_bp)
    app.register_blueprint(inventory_bp)
    app.register_blueprint(alerts_bp)

    return app

app = create_app()

if __name__ == "__main__":
    app.run(debug=True, port=5001)