import psycopg2 as ps2
from config import host, db_name


class CONNECTION:
    def __init__(self, login, password):
        self.login = login
        self.password = password
    
    def create_connection(self):
        try:
            connection = ps2.connect(
                host=host,
                user=self.login,
                password=self.password,
                database=db_name
            )
            print("[INFO] PostgreSQL connection open.")
            return connection
        except Exception as ex:
            print(f"[INFO] Error while working with PostgreSQL: {ex}")
            return None
                 
    def close_connection(self, connection):
        if connection:
            connection.close()
            print("[INFO] PostgreSQL connection closed.")


class DataBase:
    def __init__(self, user):
        self.__user = user

    def no_privilege(self, table):
        return f'У вас нет прав для просмотра или изменения {table}.'

    def transaction_error(self):
        return 'Произошла ошибка! Перезапустите приложение.'

    def select(self, table, columns='*', where=None):
        sql = f"SELECT {columns} FROM {table}"
        
        if where:
            conditions = ' AND '.join(where)
            sql += f" WHERE {conditions}"

        sql += ";"

        with self.__user.cursor() as cursor:
            try:
                cursor.execute(sql)
                rows = cursor.fetchall()
                return rows
            except ps2.errors.InsufficientPrivilege:
                self.__user.rollback()
                return self.no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                self.__user.rollback()
                return self.transaction_error()

    def insert(self, table, columns_values):
        if not columns_values:
            return 'Добавление было приостановлено. Нет информации для добавления.'
        
        columns = ', '.join(col.split('=')[0] for col in columns_values)
        values = ', '.join(col.split('=')[1].replace('"', "'") for col in columns_values)

        sql = f"INSERT INTO {table} ({columns}) VALUES ({values});"

        with self.__user.cursor() as cursor:
            try:
                cursor.execute(sql)
                self.__user.commit()
                return True
            except ps2.errors.InsufficientPrivilege:
                self.__user.rollback()
                return self.no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                self.__user.rollback()
                return self.transaction_error()

    def update(self, table, colmns = '', where = False):
        match where:
            case False:
                return 'Обновление приостановлено. Нет информации об изменяемой записи.'
            case []:
                return 'Обновление приостановлено. Нет информации об изменяемой записи.'
            
            case any:
                entrys = []
                entrys2 = []
                for i in colmns:
                    if (i.split('='))[1] != " ":
                        entrys.append(i)
                for i in where:
                    if (i.split('='))[1] != " ":
                        entrys2.append(i)
                if len(entrys) == 0:
                    return 'Введите хотя бы один параметр!'
                elif len(entrys2) == 0:
                    return 'Введите хотя бы один параметр!'
                sql = f'UPDATE {table} SET '
                for i in entrys:
                    if (len(entrys) != 1) and (i != entrys[len(entrys)-1]):
                        sql += (i+', ').replace('"', "'")
                    elif len(entrys) == 1:
                        sql += (i+' ').replace('"', "'")
                    else:
                        sql += (i+' ').replace('"', "'")
                sql += f'WHERE {entrys2[0]};'
                
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        return True
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
                    except ps2.errors.InFailedSqlTransaction as ex_:
                        self.__user.rollback()
                        return self.TransactionError()


    def delete(self, table, where=None):
        if not where:
            return 'Удаление приостановлено. Нет информации для удаления.'

        sql = f"DELETE FROM {table}"
        
        if where != 'all':
            conditions = ' AND '.join(where)
            sql += f" WHERE {conditions}"

        sql += ";"

        with self.__user.cursor() as cursor:
            try:
                cursor.execute(sql)
                self.__user.commit()
                return True
            except ps2.errors.InsufficientPrivilege:
                self.__user.rollback()
                return self.no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                self.__user.rollback()
                return self.transaction_error()