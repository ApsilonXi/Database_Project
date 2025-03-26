import psycopg2 as ps2
from datetime import datetime

host  = "127.0.0.1"
db_name = "Warehouse_DB"

connection = None

labels = {'details': 'Детали', 
          'warehouse_details_view': 'Детали', 
          'invoice': 'Накладные', 
          'invoice_details_view': 'Накладные',
          'employee': 'Сотрудники', 
          'counteragent': 'Контрагенты'}

def create_connection(log, password):
    global connection, login
    login = log
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
        return connection
    return connection

def close_connection():
    global connection
    if connection:
        connection.close()
        print("[INFO] PostgreSQL connection closed.")

def no_privilege(table):
    return f'У вас нет прав для изменения {labels[table]}.'

def transaction_error():
    return 'Произошла ошибка! Перезапустите приложение.'

def no_data():
    return 'Информации по введёным данным не существует!'

def input_error():
    return 'Произошла ошибка! Обязательные поля не заполнены.'

def error(e):
    return e

def log_action(login, action, table, details):
    with open('user_actions_log.txt', 'a', encoding='utf-8') as file:
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"{login}: {action} table {table}, {details}, time {timestamp};\n"
        file.write(log_entry)

def create_user(log, pas, role):
    create_user_sql = f"CREATE USER {log} WITH PASSWORD '{pas}';"
    grant_role = f"GRANT {role} TO {log};"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(create_user_sql)
                cursor.execute(grant_role)
                return True
            except ps2.errors.InsufficientPrivilege:
                connection.rollback()
                return no_privilege("Сотрудники")
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()

def select(table, columns='*', where=None):
    sql = f"SELECT {columns} FROM {table}"
    new_where = []
    
    if where is not None:
        for i in where:
            if i.split("=")[1] != " " and i.split("=")[1] != " ''":
                new_where.append(i)
        if len(new_where) == 0:
            return "Введите значения для поиска!"
        if len(new_where) != 1:
            conditions = ' AND '.join(new_where)
        else:
            conditions = new_where[0]
        sql += f" WHERE {conditions};"


    print(sql)
    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                rows = cursor.fetchall()
                return rows
            except ps2.errors.InsufficientPrivilege as e:
                print(e)
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()
            except ps2.errors.UndefinedColumn as e:
                print(e)
                connection.rollback()
                return no_data()
            except ps2.errors.ObjectNotInPrerequisiteState as e:
                print(e)
                connection.rollback()
                return no_privilege(table)
            except Exception as e:
                print(e)
                connection.rollback()
                return error(e)
    

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
                        valuse_list.append("'"+str(col.split(' = ')[1])+"'")
            except:
                return f'Неверно введены данные для поля {col.split('=')[0]}'

    if table != 'invoice':
        sql = f"INSERT INTO {table} ({columns}) VALUES ({", ".join(valuse_list)});"
    else:
        sql = f"INSERT INTO {table} ({columns}) VALUES ({', '.join(valuse_list[:-2])});"
        sql = f"INSERT INTO invoice_detail (detailID, quantity) VALUES ((SELECT detail_id FROM details WHERE type_detail = {valuse_list[4]} LIMIT 1), {valuse_list[5]});"

    print(sql)
    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute("BEGIN;")
                cursor.execute(sql)
                connection.commit()
                details = f"new item with values {', '.join([f'{col} = {val}' for col, val in zip(columns_list, valuse_list)])}"
                log_action(login, "insert", table, details)
                return True
            except ps2.errors.InsufficientPrivilege as e:
                print(e)
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction as e:
                print(e)
                connection.rollback()
                return transaction_error()
            except ps2.errors.NotNullViolation as e:
                print(e)
                connection.rollback()
                return input_error()
            except ps2.errors.UndefinedColumn as e:
                print(e)
                connection.rollback()
                return no_data()
            except Exception as e:
                print(e)
                connection.rollback()
                return error(e)

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
    
    if len(columns) == 0:
        return 'Разрешено обновлять только статус накладной!'
    
    new_columns = []
    new_where = []
    
    # Обработка columns и where без изменения двойных кавычек
    for i in columns:
        if (i.split("=")[1] != " ") and (i.split(" = ")[1] != "''"):
            new_columns.append(i)
    
    for i in where:
        if (i.split("=")[1] != " ") and (i.split(" = ")[1] != "''"):
            new_where.append(i)

    # Формирование SQL-запроса без замены кавычек
    sql = f'UPDATE {table} SET '
    sql += ', '.join(i for i in new_columns)  # Не меняем кавычки
    sql += f' WHERE {' AND '.join(i for i in new_where)};'

    print(sql)

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute("BEGIN;")
                cursor.execute(sql)
                connection.commit()
                details = f"item {', '.join(new_where)} new value {', '.join(new_columns)}"
                log_action(login, "update", table, details)
                return True
            except ps2.errors.InsufficientPrivilege as e:
                print(e)
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction as e:
                print(e)
                connection.rollback()
                return transaction_error()
            except ps2.errors.UndefinedColumn as e:
                print(e)
                connection.rollback()
                return no_data()
            except Exception as e:
                print(e)
                connection.rollback()
                return error(e)


def delete(table, where=None):
    if not where:
        return 'Удаление приостановлено. Нет информации для удаления.'

    sql = f"DELETE FROM {table}"

    if where != 'all':
        new_where = []
        for i in where:
            if (i.split("=")[1] != " ") and (i.split(" = ")[1] != "''"):
                new_where.append(i)
        conditions = ' AND '.join(new_where)
        sql += f" WHERE {conditions}"

    sql += ";"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute("BEGIN;")
                cursor.execute(sql)
                connection.commit()
                details = f"deleted where {', '.join(new_where)}"
                log_action(login, "delete", table, details)
                return True
            except ps2.errors.InsufficientPrivilege as e:
                print(e)
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.ForeignKeyViolation as e:
                print(e)
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction as e:
                print(e)
                connection.rollback()
                return transaction_error()
            except ps2.errors.UndefinedColumn as e:
                print(e)
                connection.rollback()
                return no_data()
            except Exception as e:
                print(e)
                connection.rollback()
                return error(e)
