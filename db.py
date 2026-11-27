from contextlib import closing

import pymysql
from flask import current_app, flash

from config import Config


def get_db_connection():
    return pymysql.connect(
        host=Config.DB_HOST,
        port=Config.DB_PORT,
        user=Config.DB_USER,
        password=Config.DB_PASSWORD,
        database=Config.DB_NAME,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
    )


def fetch_all(sql, args=None):
    with closing(get_db_connection()) as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql, args)
            return cursor.fetchall()


def write(sql, args=None):
    try:
        with closing(get_db_connection()) as connection:
            try:
                with connection.cursor() as cursor:
                    cursor.execute(sql, args)

                    # Consume any additional result sets from a CALL.
                    while cursor.nextset():
                        pass

                connection.commit()
            except pymysql.MySQLError:
                connection.rollback()
                raise
    except pymysql.MySQLError as exc:
        code = exc.args[0]

        if code == 1644:
            flash(exc.args[1], "error")
        elif code in {1048, 1062, 1264, 1292, 1406, 1451, 1452, 3819, 4025}:
            flash(
                "This change violates a database rule or affects a referenced record.",
                "error",
            )
        else:
            current_app.logger.exception("Database write failed")
            flash("The database could not save this change.", "error")

        return False

    return True