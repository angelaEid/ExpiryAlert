# ExpiryAlert

ExpiryAlert is a COE 418 Flask and MariaDB application for tracking restaurant purchases, inventory lots, expiration alerts, and food waste.

## Run locally on Windows

1. For a **fresh MariaDB instance**, run `sql/01_schema.sql` through `sql/07_security.sql` in order using a database installer account. Use a SQL client that understands `DELIMITER`, such as the MariaDB CLI, for script 05. In a private copy of script 07, replace the two password placeholders with distinct strong passwords. Existing installations can start at step 2.
2. Create a private `.env` file in the project root, or use the existing one. Set `DB_HOST=127.0.0.1`, `DB_PORT` to the MariaDB port (usually 3306), `DB_NAME=expiryalert`, `DB_USER=expiry_final_app`, `DB_PASSWORD` to the application account's password, and `SECRET_KEY` to a long random value. Keep `.env` and the private SQL copy out of version control and the submission ZIP.
3. Run the following in PowerShell from the project root.

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\python.exe -m pip install -r requirements.txt
   .\.venv\Scripts\python.exe app.py
   ```

4. Open [ExpiryAlert](http://127.0.0.1:5001). The development server is intended for a local demo.

## Demo workflow

Add a product and link it to a supplier in Products. Create a purchase in Purchases, then receive a partial quantity under Inventory → Add Batch. Open the batch's Stock Activity to record usage and waste, and filter Reports by branch to review stock and losses. Generate alerts in Expiration Alerts and acknowledge one. Refreshing again on the same day preserves the acknowledgment for the same batch and alert type.

See [verification notes](docs/verification.md) for observed results and the coursework evidence still needed.

## Team and AI assistance

Group 10 should add the final member names and actual responsibilities before submission. OpenAI Codex assisted with repository and course material review, test execution and interpretation, form-token validation, installation credential placeholders, and project documentation during this session. The application and database already existed when this session started. Team members should verify the final work and disclose any additional AI use.
