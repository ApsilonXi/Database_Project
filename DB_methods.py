import psycopg2 as ps2
from config import host, db_name

class CONNECTION:
    def __init__(self, login, password):
        self.login = login
        self.password = password
    
    def CreateConnection(self):
        try:
            connection = ps2.connect(
                host=host,
                user=self.login,
                password=self.password,
                database=db_name
            )
            print("[INFO] PostgreSQL connection open.")
            return connection

        except Exception as _ex:
            print("[INFO] Error while working  with PostgreSQL.", _ex)
            return 0
                 
    def CloseConnection(self, connection):
        if connection:
            connection.close()
            print("[INFO] PostgreSQL connection closed.")

class DataBase():
    def __init__(self, user):
        self.__user = user

    def NoPrivilege(self, table):
        return f'У вас нет прав для просмотра или изменения {table}.'

    def SELECT(self, table, colmn = '', where = False):
        match where:
            case False:
                sql = f"SELECT * FROM {table};"
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        rows = cursor.fetchall()
                        return rows
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
            case False:
                sql = f"SELECT * FROM {table} WHERE {where};"
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        rows = cursor.fetchall()
                        return rows
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
            
    def INSER(self):
        pass

    def DELETE(self):
        pass

    def DROP(self):
        pass

    def ALTER(self):
        pass


