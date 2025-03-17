import psycopg2 as ps2
from datetime import datetime

host  = "127.0.0.1"
db_name = "Warehouse_DB"

connection = None

labels = {'details': 'Детали', 'invoice': 'Накладыне', 'employee': 'Сотрудники', 'counteragent': 'Контрагенты'}

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

def input_error():
    return 'Произошла ошибка! Обязательные поля не заполнены.'

def log_action(login, action, table, details):
    with open('user_actions_log.txt', 'a', encoding='utf-8') as file:
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"{login}: {action} table {table}, {details}, time {timestamp};\n"
        file.write(log_entry)

def select(table, columns='*', where=None):
    sql = f"SELECT {columns} FROM {table}"
    new_where = []
    
    if where != None:
        if table == "invoice":
            sql = """
            SELECT
                inv.invoice_id,
                inv.counteragentID,
                inv.date_time,
                inv.type_invoice,
                inv.status,
                invd.detailID,
                invd.quantity,
                det.type_detail
            FROM
                invoice inv
            JOIN
                invoice_detail invd ON inv.invoice_id = invd.invoiceID
            JOIN
                details det ON invd.detailID = det.detail_id
            WHERE 1=1 """

            if where[0].split("=")[1] != ' ':  # invoice_id
                sql += f"inv.invoice_id = {where[0].split(" = ")[1]}"

            if where[1].split("=")[1] != ' ':  # counteragentID
                sql += f" AND inv.counteragentID = {where[1].split(" = ")[1]}"

            if where[2].split("=")[1] != ' ':  # date_time
                sql += f" AND inv.date_time = '{where[2].split(" = ")[1]}'"

            if where[3].split("=")[1] != ' ':  # type_invoice
                sql += f" AND inv.type_invoice = {where[3].split(" = ")[1]}"

            if where[4].split("=")[1] != ' ':  # status
                sql += f" AND inv.status = {where[4].split(" = ")[1]}"

            if where[5].split("=")[1] != ' ':  # type_detail (в таблице details)
                sql += f" AND invd.detailID = (SELECT detail_id FROM details WHERE type_detail = '{where[5].split(" = ")[1]}' LIMIT 1)"

            if where[6].split("=")[1] != ' ':  # quantity
                sql += f" AND invd.quantity = {where[6].split(" = ")[1]}"

        else:
            for i in where:
                if (i.split("=")[1] != " ") and (i.split("=")[1] != " ''"):
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
                        valuse_list.append("'"+str(col.split(' = ')[1])+"'")
            except:
                return f'Неверно введены данные для поля {col.split('=')[0]}'

    if table != 'invoice':
        sql = f"INSERT INTO {table} ({columns}) VALUES ({", ".join(valuse_list)});"
    else:
        sql = f"INSERT INTO {table} ({columns}) VALUES ({', '.join(valuse_list[:-2])});"
        sql = f"INSERT INTO invoice_detail (detailID, quantity) VALUES ((SELECT detail_id FROM details WHERE type_detail = {valuse_list[4]} LIMIT 1), {valuse_list[5]});"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                connection.commit()
                details = f"new item with values {', '.join([f'{col} = {val}' for col, val in zip(columns_list, valuse_list)])}"
                log_action(login, "insert", table, details)
                return True
            except ps2.errors.InsufficientPrivilege as e:
                print(e)
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()
            except ps2.errors.NotNullViolation:
                connection.rollback()
                return input_error()

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
        if (i.split("=")[1] != " ") and (i.split(" = ")[1] != "''"):
            new_where.append(i)

    sql = f'UPDATE {table} SET '
    sql += ', '.join(i.replace('"', "'") for i in new_columns)
    sql += f' WHERE {', '.join(i.replace('"', "'") for i in new_where)};'

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                connection.commit()
                details = f"item {', '.join(new_where)} new value {', '.join(new_columns)}"
                log_action(login, "update", table, details)
                return True
            except ps2.errors.InsufficientPrivilege as e:
                connection.rollback()
                print(e)
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
            if (i.split("=")[1] != " ") and (i.split(" = ")[1] != "''"):
                new_where.append(i)
        conditions = ' AND '.join(new_where)
        sql += f" WHERE {conditions}"

    sql += ";"

    if connection:
        with connection.cursor() as cursor:
            try:
                cursor.execute(sql)
                connection.commit()
                details = f"deleted where {', '.join(new_where)}"
                log_action(login, "delete", table, details)
                return True
            except ps2.errors.InsufficientPrivilege:
                connection.rollback()
                return no_privilege(table)
            except ps2.errors.InFailedSqlTransaction:
                connection.rollback()
                return transaction_error()
