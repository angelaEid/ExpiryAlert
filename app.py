from hmac import compare_digest
from secrets import token_urlsafe

from flask import Flask, abort, request, session
from dotenv import load_dotenv
import os

from routes.operations import operations_bp
from routes.main import main_bp
from routes.inventory import inventory_bp
from routes.alerts import alerts_bp

# Load environment variables from .env
load_dotenv()

def create_app():
    app = Flask(__name__)

    # Enable Flask sessions and flash messages
    app.config["SECRET_KEY"] = os.environ["SECRET_KEY"]

    @app.before_request
    def protect_form_submissions():
        if request.method == "POST":
            expected = session.get("csrf_token")
            supplied = request.form.get("csrf_token", "")
            if not expected or not compare_digest(expected.encode(), supplied.encode()):
                abort(400, description="Invalid form token. Reload the page and try again.")
        elif request.method == "GET" and "csrf_token" not in session:
            session["csrf_token"] = token_urlsafe(32)


    app.register_blueprint(main_bp)
    app.register_blueprint(operations_bp)
    app.register_blueprint(inventory_bp)
    app.register_blueprint(alerts_bp)

    return app

app = create_app()

if __name__ == "__main__":
    app.run(debug=True, port=5001)
