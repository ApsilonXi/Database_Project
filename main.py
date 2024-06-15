import psycopg2 as ps2

class DataBase:
    def __init__(self, host, db_name, login, password):
        try:
            self.connection = ps2.connect(
                host=host,
                user=login,
                password=password,
                database=db_name
            )
            print("[INFO] PostgreSQL connection open.")

        except Exception as _ex:
            print("[INFO] Error while working  with PostgreSQL.", _ex)


    def CloseConnection(self):
        if self.connection:
            self.connection.close()
            print("[INFO] PostgreSQL connection closed.")


