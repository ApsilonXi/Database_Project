import psycopg2 as ps2
from config import host, db_name

connection = None

def create_connection(login, password):
    global connection
    try:
        connection = ps2.connect(
            host=host,
            user=login,
            password=password,
            database=db_name
        )
        print("[INFO] PostgreSQL connection open.")
    except Exception as ex:
        print(f"[INFO] Error while working with PostgreSQL: {ex}")
        connection = None
    return connection

def close_connection():
    global connection
    if connection:
        connection.close()
        print("[INFO] PostgreSQL connection closed.")

def no_privilege(table):
    return f'У вас нет прав для изменения {table}.'

def transaction_error():
    return 'Произошла ошибка! Перезапустите приложение.'

def select(table, columns='*', where=None):
    sql = f"SELECT {columns} FROM {table}"
    new_where = []
    
    if where != None:
        for i in where:
            if i.split("=")[1] != " ":
                new_where.append(i)
        if len(new_where) == 0:
            return "Введите значения для поиска!"
        if len(new_where) != 1:
            conditions = ' AND '.join(new_where)
        else:
            conditions = new_where[0]
        sql += f" WHERE {conditions};"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                rows = cursor.fetchall()
                return rows
            except ps2.errors.InsufficientPrivilege:
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()

def insert(table, columns_values):
    if not columns_values:
        return 'Добавление было приостановлено. Нет информации для добавления.'
    
    columns_list = []
    for col in columns_values:
        if col.split('=')[1] != " ":
            columns_list.append(col.split('=')[0])
    columns = ', '.join(columns_list)

    valuse_list = []
    for col in columns_values:
        try:
            if int(col.split('=')[1]):
                valuse_list.append(str(col.split('=')[1]))
        except:
            try:
                if str(col.split('=')[1]):
                    if col.split('=')[1] != " ":
                        valuse_list.append("'"+str(col.split('=')[1])+"'")
            except:
                return f'Неверно введены данные для поля {col.split('=')[0]}'
    values = ', '.join(valuse_list)

    sql = f"INSERT INTO {table} ({columns}) VALUES ({values});"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                connection.commit()
                return True
            except ps2.errors.InsufficientPrivilege:
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()

def update(table, columns='', where=False):
    if not where:
        return 'Обновление приостановлено. Нет информации об изменяемой записи.'
    if not columns:
        return 'Обновление приостановлено. Нет информации для изменения записи.'
    k = 0
    for i in where:
        if i.split('=')[1] == "":
            k += 1
    if len(where) == k:
        return 'Введите хотя бы одно условие для обновления!'
    
    new_columns = []
    new_where = []
    for i in columns:
        if i.split("=")[1] != " ":
            new_columns.append(i)
    for i in where:
        if i.split("=")[1] != " ":
            new_where.append(i)

    sql = f'UPDATE {table} SET '
    sql += ', '.join(i.replace('"', "'") for i in new_columns)
    sql += f' WHERE {', '.join(i.replace('"', "'") for i in new_where)};'

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                connection.commit()
                return True
            except ps2.errors.InsufficientPrivilege:
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()

def delete(table, where=None):
    if not where:
        return 'Удаление приостановлено. Нет информации для удаления.'

    sql = f"DELETE FROM {table}"

    if where != 'all':
        new_where = []
        for i in where:
            if i.split("=")[1] != " ":
                new_where.append(i)
        conditions = ' AND '.join(new_where)
        sql += f" WHERE {conditions}"

    sql += ";"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                connection.commit()
                return True
            except ps2.errors.InsufficientPrivilege:
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()
