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

    def TransactionError(self):
        return 'Произошла ошибка! Перезапустите приложение.'

    def SELECT(self, table, colmn = '', where = False):
        match where:
            case False:
                sql = f"SELECT {colmn} FROM {table};"
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        rows = cursor.fetchall()
                        return rows
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
            case any:
                entrys = []
                for i in where:
                    if (i.split('='))[1] != " ":
                        entrys.append(i)
                if len(entrys) == 0:
                    return 'Введите хотя бы один параметр!'
                sql = f"SELECT {colmn} FROM {table} WHERE "
                for i in entrys:
                    if (len(entrys) != 1) and (i != entrys[len(entrys)-1]):
                        sql += i+', '
                    elif len(entrys) == 1:
                        sql += i
                    else:
                        sql += ';'
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        rows = cursor.fetchall()
                        return rows
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
                    except ps2.errors.InFailedSqlTransaction as ex_:
                        self.__user.rollback()
                        return self.TransactionError()
            
    def INSERT(self, table, colmns = False):
        match colmns:
            case False:
                return 'Добавление было приоставновлено. Нет информации для добавления.'
            
            case any:
                entrys = []
                sql = f"INSERT INTO {table}("
                for i in colmns:
                    if (i.split('='))[1] != " ":
                        if ('id' not in (i.split('='))[0]) or ('ID' not in (i.split('='))[0]): 
                            entrys.append(i)
                            sql += (i.split('=')[0]) + ','
                sql = sql[:len(sql)-1]
                sql += ') VALUES ('
                if len(entrys) == 0:
                    return 'Добавление было приоставновлено. Проверьте введённые значения.'
                for i in entrys:
                    if (len(entrys) != 1) and (i != entrys[len(entrys)-1]):
                        sql += ((i.split(' = '))[1]).replace('"', "'")+','
                    else:
                        sql = sql[:len(sql)-1]
                        sql += ','+((i.split(' = '))[1]).replace('"', "'")+');'
                    
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        rows = cursor.fetchall()
                        return True
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
                    except ps2.errors.InFailedSqlTransaction as ex_:
                        self.__user.rollback()
                        return self.TransactionError(table)

    def UPDATE(self, table, colmns = '', where = False):
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


    def DELETE(self, table, where = False):
        match where:
            case False:
                return 'Удаление приостановлено. Нет информации об удаляемой записи.'
            
            case 'all':
                sql = f'DELETE FROM {table};'
                with self.__user.cursor() as cursor:
                    try:
                        cursor.execute(sql)
                        return True
                    except ps2.errors.InsufficientPrivilege as ex_:
                        self.__user.rollback()
                        return self.NoPrivilege(table)
            
            case any:
                entrys = []
                for i in where:
                    if (i.split('='))[1] != " ":
                        entrys.append(i)
                if len(entrys) == 0:
                    return 'Введите хотя бы один параметр!'
                sql = f'DELETE FROM {table} WHERE '
                for i in entrys:
                    if (len(entrys) != 1) and (i != entrys[len(entrys)-1]):
                        sql += i+', '
                    elif len(entrys) == 1:
                        sql += i
                    else:
                        sql += ';'
                
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



