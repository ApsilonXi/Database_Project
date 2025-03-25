from tkinter import *
from tkinter import ttk, messagebox, Menu
import DB_methods as db
from datetime import datetime
import subprocess, os

def quit_programm():
    if messagebox.askokcancel('Выход', 'Действительно хотите закрыть окно?'):
        db.close_connection()
        quit()

def clear_window(window):
    for widget in window.winfo_children():
        widget.destroy()

def convert_to_standard_format(date_str):
    date_formats = [
        "%Y-%m-%d %H:%M:%S",   # ГГГГ-ММ-ДД ЧЧ:ММ:СС
        "%d.%m.%Y %H:%M:%S",   # ДД.ММ.ГГГГ ЧЧ:ММ:СС
        "%d/%m/%Y %H:%M:%S",   # ДД/ММ/ГГГГ ЧЧ:ММ:СС
        "%Y-%m-%d",            # ГГГГ-ММ-ДД
        "%d.%m.%Y",            # ДД.ММ.ГГГГ
        "%d/%m/%Y",            # ДД/ММ/ГГГГ
        "%H:%M:%S",            # ЧЧ:ММ:СС
        "%d-%m-%Y",            # ДД-ММ-ГГГГ
    ]
    
    if len(date_str.split()) == 2 and len(date_str.split()[1].split(":")) == 2:
        date_str += ":00"  

    for fmt in date_formats:
        try:
            date_obj = datetime.strptime(date_str, fmt)
            return date_obj.strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            continue
    return False

'''def create_user():
    window.title("Добавление пользователя")
    window.geometry('%dx%d+%d+%d' % (500, 500, (window.winfo_screenwidth() / 2) - (1000 / 2), (window.winfo_screenheight() / 2) - (800 / 2)))'''

    
def create_backup():
    os.environ['PGPASSWORD'] = password

    pg_dump_path = r"C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"
    username = login
    host = "127.0.0.1"
    port = "5432"
    database = "Warehouse_DB"
    backup_file = os.path.join('sql\\backup\\', f"{database}_backup_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.sql")

    command = [
        pg_dump_path, 
        "-U", username, 
        "-h", host, 
        "-p", port, 
        "-F", "p", 
        "-f", backup_file, 
        database
    ]

    try:
        result = subprocess.run(command, check=True, text=True, capture_output=True)
        messagebox.showinfo("Успех", "Резервное копирование успешно завершено!")
    except subprocess.CalledProcessError as e:
        messagebox.showerror("Ошибка", f"Ошибка при создании бекапа: {e}")

def create_main_window(win, log, user, pas):
    global active_user, window, login, password
    window = win
    active_user = user
    login = log
    password = pas

    clear_window(window)

    window.title("Склад запчастей")
    window.geometry('%dx%d+%d+%d' % (1100, 800, (window.winfo_screenwidth() / 2) - (1000 / 2), (window.winfo_screenheight() / 2) - (800 / 2)))

    window.option_add("*tearOff", FALSE)

    find_menu = Menu()
    find_menu.add_command(label="Деталь", command=create_select_detail)
    find_menu.add_command(label='Накладная', command=create_select_invoice)
    find_menu.add_command(label="Сотрудник", command=create_select_employee)
    find_menu.add_command(label="Контрагент", command=create_select_counteragent)

    menu = Menu()
    menu.add_cascade(label="Найти", menu=find_menu)
    menu.add_command(label="Выход", command=quit_programm)

    window.config(menu=menu)

    label_title = ttk.Label(window, text=f'Добро пожаловать, {login}!', font=("arial", 30, "bold"), background="#FFFAFA")
    label_title.place(x=1000 // 2, y=(800 // 2)-300, anchor='center')

    # Кнопка для резервного копирования
    backup_button = ttk.Button(window, text="Резервное копирование", command=create_backup)
    backup_button.place(x=1000 // 2, y=(800 // 2)-200, anchor='center')  # Разместить кнопку немного ниже заголовка

    # Кнопка для создания пользователей
    '''backup_button = ttk.Button(window, text="Добавить пользователя", command=create_user)
    backup_button.place(x=1000 // 2, y=(800 // 2)-50, anchor='center')''' 

    window.protocol("WM_DELETE_WINDOW", quit_programm)

def menu_window(window, table, columns):
    label_title = ttk.Label(window, text=f'{table}', font=("arial", 30, "bold"), background="#FFFAFA")
    label_title.place(x=10, y=15)

    x_label, y_label, n = 15, 70, 0
    ENTRYS_LIST = []
    ENTRYS_LIST_titles = []

    window.option_add("*tearOff", FALSE)
    menu = Menu()
    menu.add_cascade(label="Назад", command=lambda: create_main_window(window, login, active_user, password))
    menu.add_command(label="Выход", command=quit_programm)
    window.config(menu=menu)

    for num in range(len(columns)):
        new_title = ttk.Label(window, text=columns[num], font=("arial", 15), background='#FFFAFA')
        new_title.place(x=x_label, y=y_label)
        new_input = ttk.Entry(window, width=15, background='#FFFAFA')
        new_input.place(x=x_label + 140, y=y_label + 5)
        ENTRYS_LIST.append(new_input)
        ENTRYS_LIST_titles.append(columns[num])
        y_label += 40
        n += 1
        if n == 3:
            n = 0
            x_label += 250
            y_label = 70

    btn_find = ttk.Button(window, text='Найти', command=lambda: find_item(ENTRYS_LIST, label_title))
    btn_insert = ttk.Button(window, text='Добавить', command=lambda: insert_item(ENTRYS_LIST, label_title))
    btn_update = ttk.Button(window, text='Изменить', command=lambda: where_update(ENTRYS_LIST_titles, ENTRYS_LIST, label_title))
    btn_delete = ttk.Button(window, text='Удалить', command=lambda: delete_item(ENTRYS_LIST, label_title))

    btn_find.place(x=15, y=200)
    btn_insert.place(x=135, y=200)
    btn_update.place(x=255, y=200)
    btn_delete.place(x=375, y=200)

    window.protocol("WM_DELETE_WINDOW", quit_programm)

#методы бд
def find_item(ENTRYS_LIST, label_title):
    entries = [entry.get() for entry in ENTRYS_LIST]
    if label_title.cget('text') == 'Детали':
        res_sql = db.select('warehouse_details_view', '*', [f'warehouse_number = {entries[0]}',
                                                            f'room_number = {entries[1]}',
                                                            f'rack_number = {entries[2]}',
                                                            f'shelf_number = {entries[3]}',
                                                            f'detail_id = {entries[4]}',
                                                            f'type_detail = {"'"+entries[5]+"'"}',
                                                            f'weight = {entries[6]}'])
        if type(res_sql) == str:
            messagebox.showerror('Нет результата', res_sql)
        elif len(res_sql) == 0:
            messagebox.showerror('Результат запроса', 'По вашему запросу ничего не найдено')
        else:
            new_window(('Склад', 'Комната', 'Стеллаж','Полка', 'Тип', 'Вес', 'ID'), res_sql)

    elif label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entries[2])
        '''if entries[3] == 'выгрузка':
            type_inv = True
        elif entries[3] == 'отгрузка':
            type_inv = False
        else:
            type_inv = ''
        if entries[4] == "в процессе":
            status = False
        elif entries[4] == "завершено":
            status = False
        else:
            status = '''''
        if (date == False) and (entries[2] != ""):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif entries[2] == "":
            res_sql = db.select('invoice_details_view', '*', [f'invoice_id = {entries[0]}',
                                                                f'counteragent_name = {"'"+entries[1]+"'"}',
                                                                f'date_time::date = {entries[2]}',
                                                                f'type_invoice = {entries[3]}',
                                                                f'status = {entries[4]}',
                                                                f'type_detail = {"'"+entries[5]+"'"}',
                                                                f'quantity = {entries[6]}',
                                                                f'responsible_last_name = {"'"+entries[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entries[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entries[9]+"'"}'])
        else:
            res_sql = db.select('invoice_details_view', '*', [f'invoice_id = {entries[0]}',
                                                                f'counteragent_name = {"'"+entries[1]+"'"}',
                                                                f'date_time::date = {"'"+entries[2]+"'"}',
                                                                f'type_invoice = {entries[3]}',
                                                                f'status = {"'"+entries[4]+"'"}',
                                                                f'type_detail = {"'"+entries[5]+"'"}',
                                                                f'quantity = {entries[6]}',
                                                                f'responsible_last_name = {"'"+entries[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entries[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entries[9]+"'"}'])
        if type(res_sql) == str:
            messagebox.showerror('Нет результата', res_sql)
        elif len(res_sql) == 0:
            messagebox.showerror('Результат запроса', 'По вашему запросу ничего не найдено')
        else:
            new_window(('ID', 'Контрагент', 'Время', 'Тип', 'Статус', "Деталь", "Количество", "Фамилия", "Имя", "Отчество"), res_sql)

    elif label_title.cget('text') == 'Сотрудники':
        res_sql = db.select('employee', '*', [f'employee_id = {entries[0]}',
                                                f'employee_role = {"'"+entries[1]+"'"}',
                                                f'last_name = {"'"+entries[2]+"'"}',
                                                f'first_name = {"'"+entries[3]+"'"}',
                                                f'patronymic = {"'"+entries[4]+"'"}'])
        if type(res_sql) == str:
            messagebox.showerror('Нет результата', res_sql)
        elif len(res_sql) == 0:
            messagebox.showerror('Результат запроса', 'По вашему запросу ничего не найдено')
        else:
            new_window(('ID', 'Должность', 'Фамилия', 'Имя', 'Отчество'), res_sql)

    elif label_title.cget('text') == 'Контрагенты':
        res_sql = db.select('counteragent', '*', [f'counteragent_id = {entries[0]}',
                                                    f'counteragent_name = {"'"+entries[1]+"'"}',
                                                    f'contact_person = {"'"+entries[2]+"'"}',
                                                    f'phone_number = {entries[3]}',
                                                    f'address = {"'"+entries[4]+"'"}'])
        if type(res_sql) == str:
            messagebox.showerror('Нет результата', res_sql)
        elif len(res_sql) == 0:
            messagebox.showerror('Результат запроса', 'По вашему запросу ничего не найдено')
        else:
            new_window(('ID', 'Контрагент', 'Представиль', 'Телефон', 'Адрес'), res_sql)

def insert_item(ENTRYS_LIST, label_title):
    entries = [entry.get() for entry in ENTRYS_LIST]
    if label_title.cget('text') == 'Детали':
        res_sql = db.insert('warehouse_details_view', [f'warehouse_number = {entries[0]}',
                                                            f'room_number = {entries[1]}',
                                                            f'rack_number = {entries[2]}',
                                                            f'shelf_number = {entries[3]}',
                                                            f'detail_id = {entries[4]}',
                                                            f'type_detail = {entries[5]}',
                                                            f'weight = {entries[6]}'])   

    elif label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entries[2])
        if (date == False) and (entries[2] != ""):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif entries[2] == "":
            res_sql = db.insert('invoice_details_view', [f'invoice_id = {entries[0]}',
                                                            f'counteragent_name = {entries[1]}',
                                                            f'date_time = {entries[2]}',
                                                            f'type_invoice = {"'"+entries[3]+"'"}',
                                                            f'status = {"'"+entries[4]+"'"}',
                                                            f'type_detail = {"'"+entries[5]+"'"}',
                                                            f'quantity = {entries[6]}',
                                                            f'responsible_last_name = {"'"+entries[7]+"'"}',
                                                            f'responsible_first_name = {"'"+entries[8]+"'"}',
                                                            f'responsible_patronymic = {"'"+entries[9]+"'"}'])
        else:
            res_sql = db.insert('invoice_details_view', [f'invoice_id = {entries[0]}',
                                                            f'counteragent_name = {entries[1]}',
                                                            f'date_time = {entries[2]}',
                                                            f'type_invoice = {entries[3]}',
                                                            f'status = {entries[4]}',
                                                            f'type_detail = {entries[5]}',
                                                            f'quantity = {entries[6]}',
                                                            f'responsible_last_name = {entries[7]}',
                                                            f'responsible_first_name = {entries[8]}',
                                                            f'responsible_patronymic = {entries[9]}'])

    elif label_title.cget('text') == 'Сотрудники':
        res_sql = db.insert('employee', [f'employee_id = {entries[0]}',
                                             f'employee_role = {entries[1]}',
                                             f'last_name = {entries[2]}',
                                             f'first_name = {entries[3]}',
                                             f'patronymic = {entries[4]}'])

    elif label_title.cget('text') == 'Контрагенты':
        res_sql = db.insert('counteragent', [f'counteragent_id = {entries[0]}',
                                                f'counteragent_name = {entries[1]}',
                                                f'contact_person = {entries[2]}',
                                                f'phone_number = {entries[3]}',
                                                f'address = {entries[4]}'])
        
    if res_sql != True:
        messagebox.showerror('Ошибка', res_sql)
    else:
        messagebox.showinfo('Результат', 'Добавление прошло успешно!')
        
def delete_item(ENTRYS_LIST, label_title):
    entries = [entry.get() for entry in ENTRYS_LIST]
    if label_title.cget('text') == 'Детали':
        res_sql = db.delete('warehouse_details_view', [f'warehouse_number = {entries[0]}',
                                                            f'room_number = {entries[1]}',
                                                            f'rack_number = {entries[2]}',
                                                            f'shelf_number = {entries[3]}',
                                                            f'detail_id = {entries[4]}',
                                                            f'type_detail = {"'"+entries[5]+"'"}',
                                                            f'weight = {entries[6]}'])

    elif label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entries[2])
        if (date == False) and (entries[2] != ""):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif entries[2] == "":
            res_sql = db.delete('invoice_details_view', [f'invoice_id = {entries[0]}',
                                                            f'counteragent_name = {"'"+entries[1]+"'"}',
                                                            f'date_time::date = {entries[2]}',
                                                            f'type_invoice = {entries[3]}',
                                                            f'status = {entries[4]}',
                                                            f'type_detail = {"'"+entries[5]+"'"}',
                                                            f'quantity = {entries[6]}',
                                                            f'responsible_last_name = {"'"+entries[7]+"'"}',
                                                            f'responsible_first_name = {"'"+entries[8]+"'"}',
                                                            f'responsible_patronymic = {"'"+entries[9]+"'"}'])
        else:
            res_sql = db.delete('invoice_details_view', [f'invoice_id = {entries[0]}',
                                                            f'counteragent_name = {"'"+entries[1]+"'"}',
                                                            f'date_time::date = {"'"+entries[2]+"'"}',
                                                            f'type_invoice = {entries[3]}',
                                                            f'status = {entries[4]}',
                                                            f'type_detail = {"'"+entries[5]+"'"}',
                                                            f'quantity = {entries[6]}',
                                                            f'responsible_last_name = {"'"+entries[7]+"'"}',
                                                            f'responsible_first_name = {"'"+entries[8]+"'"}',
                                                            f'responsible_patronymic = {"'"+entries[9]+"'"}'])
    
    elif label_title.cget('text') == 'Сотрудники':
        res_sql = db.delete('employee', [f'employee_id = {entries[0]}',
                                             f'employee_role = {"'"+entries[1]+"'"}',
                                             f'last_name = {"'"+entries[2]+"'"}',
                                             f'first_name = {"'"+entries[3]+"'"}',
                                             f'patronymic = {"'"+entries[4]+"'"}'])
        
    elif label_title.cget('text') == 'Контрагенты':
        res_sql = db.delete('counteragent', [f'counteragent_id = {entries[0]}',
                                                f'counteragent_name = {"'"+entries[1]+"'"}',
                                                f'contact_person = {"'"+entries[2]+"'"}',
                                                f'phone_number = {entries[3]}',
                                                f'address = {"'"+entries[4]+"'"}'])

    if res_sql != True:
        messagebox.showerror('Ошибка', res_sql)
    else:
        messagebox.showinfo('Результат', 'Удаление прошло успешно!')
        
def where_update(colmns, ENTRYS_LIST, label_title):
    global toplev
    k = 0
    for i in [entry.get() for entry in ENTRYS_LIST]:
        if i == "":
            k += 1
    if len([entry.get() for entry in ENTRYS_LIST]) == k:
        messagebox.showerror('Ошибка', 'Введите хотя бы один параметр!')
        return 0
    toplev = Toplevel()
    toplev.geometry('1000x400')
    toplev.title('Новые данные')
    ENTRYS_LIST_wheres = []
    x_label, y_label, n = 15, 70, 0
    for num in range(len(colmns)):
        new_title = ttk.Label(master=toplev, text=colmns[num], font=("arial", 15), background='#FFFAFA')
        new_title.place(x=x_label, y=y_label)
        new_input = ttk.Entry(master=toplev, width=15, background='#FFFAFA')
        new_input.place(x=x_label + 120, y=y_label + 5)
        ENTRYS_LIST_wheres.append(new_input)
        y_label += 40
        n += 1
        if n == 3:
            x_label += 250
            y_label, n = 70, 0
    btn_update = ttk.Button(master=toplev, text='Изменить', command=lambda: update_item(ENTRYS_LIST_wheres, ENTRYS_LIST, label_title))
    btn_update.place(x=15, y=250)

def update_item(ENTRYS_LIST, ENTRYS_LIST_wheres, label_title):
    entrys1 = [entry.get() for entry in ENTRYS_LIST]
    entrys2 = [entry.get() for entry in ENTRYS_LIST_wheres]
    if label_title.cget('text') == 'Детали':
        res_sql = db.update('warehouse_details_view', [f'warehouse_number = {entrys1[0]}',
                                                            f'room_number = {entrys1[1]}',
                                                            f'rack_number = {entrys1[2]}',
                                                            f'shelf_number = {entrys1[3]}',
                                                            f'detail_id = {entrys1[4]}',
                                                            f'type_detail = {"'"+entrys1[5]+"'"}',
                                                            f'weight = {entrys1[6]}'],
                                                        [f'warehouse_number = {entrys2[0]}',
                                                            f'room_number = {entrys2[1]}',
                                                            f'rack_number = {entrys2[2]}',
                                                            f'shelf_number = {entrys2[3]}',
                                                            f'detail_id = {entrys2[4]}',
                                                            f'type_detail = {"'"+entrys2[5]+"'"}',
                                                            f'weight = {entrys2[6]}'])

    elif label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entrys1[2])
        date2 = convert_to_standard_format(entrys2[2])
        if (date == False) and ((entrys1[2] != "") or (entrys2[2] != "")):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif (entrys1[2] == "") and (entrys2[2] == ""):
            res_sql = db.update('invoice_details_view', [f'invoice_id = {entrys1[0]}',
                                                            f'counteragent_name = {"'"+entrys1[1]+"'"}',
                                                            f'date_time = {entrys1[2]}',
                                                            f'type_invoice = {"'"+entrys1[3]+"'"}',
                                                            f'status = {"'"+entrys1[4]+"'"}',
                                                            f'type_detail = {"'"+entrys1[5]+"'"}',
                                                            f'quantity = {entrys1[6]}',
                                                            f'responsible_last_name = {"'"+entrys1[7]+"'"}',
                                                            f'responsible_first_name = {"'"+entrys1[8]+"'"}',
                                                            f'responsible_patronymic = {"'"+entrys1[9]+"'"}'], 
                                                        [f'invoice_id = {entrys2[0]}',
                                                            f'counteragent_name = {"'"+entrys2[1]+"'"}',
                                                            f'date_time = {entrys2[2]}',
                                                            f'type_invoice = {"'"+entrys2[3]+"'"}',
                                                            f'status = {"'"+entrys2[4]+"'"}',
                                                            f'type_detail = {"'"+entrys2[5]+"'"}',
                                                            f'quantity = {entrys2[6]}',
                                                            f'responsible_last_name = {"'"+entrys2[7]+"'"}',
                                                            f'responsible_first_name = {"'"+entrys2[8]+"'"}',
                                                            f'responsible_patronymic = {"'"+entrys2[9]+"'"}'])
        else:
            if (entrys1[2] != "") and ((entrys2[2] == "")):
                res_sql = db.update('invoice_details_view', [f'invoice_id = {entrys1[0]}',
                                                                f'counteragent_name = {entrys1[1]}',
                                                                f'date_time = {"'"+date+"'"}',
                                                                f'type_invoice = {"'"+entrys1[3]+"'"}',
                                                                f'status = {"'"+entrys1[4]+"'"}',
                                                                f'type_detail = {"'"+entrys1[5]+"'"}',
                                                                f'quantity = {entrys1[6]}',
                                                                f'responsible_last_name = {"'"+entrys1[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entrys1[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entrys1[9]+"'"}'], 
                                                            [f'invoice_id = {entrys2[0]}',
                                                                f'counteragent_name = {entrys2[1]}',
                                                                f'date_time = {entrys2[2]}',
                                                                f'type_invoice = {"'"+entrys2[3]+"'"}',
                                                                f'status = {"'"+entrys2[4]+"'"}',
                                                                f'type_detail = {"'"+entrys2[5]+"'"}',
                                                                f'quantity = {entrys2[6]}',
                                                                f'responsible_last_name = {"'"+entrys2[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entrys2[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entrys2[9]+"'"}'])
            elif (entrys1[2] == "") and ((entrys2[2] != "")):
                res_sql = db.update('invoice_details_view', [f'invoice_id = {entrys1[0]}',
                                                                f'counteragent_name = {entrys1[1]}',
                                                                f'date_time = {entrys1[2]}',
                                                                f'type_invoice = {"'"+entrys1[3]+"'"}',
                                                                f'status = {"'"+entrys1[4]+"'"}',
                                                                f'type_detail = {"'"+entrys1[5]+"'"}',
                                                                f'quantity = {entrys1[6]}',
                                                                f'responsible_last_name = {"'"+entrys1[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entrys1[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entrys1[9]+"'"}'], 
                                                            [f'invoice_id = {entrys2[0]}',
                                                                f'counteragent_name = {entrys2[1]}',
                                                                f'date_time = {"'"+date2+"'"}',
                                                                f'type_invoice = {"'"+entrys2[3]+"'"}',
                                                                f'status = {"'"+entrys2[4]+"'"}',
                                                                f'type_detail = {"'"+entrys2[5]+"'"}',
                                                                f'quantity = {entrys2[6]}',
                                                                f'responsible_last_name = {"'"+entrys2[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entrys2[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entrys2[9]+"'"}'])  
            elif (entrys1[2] != "") and ((entrys2[2] != "")):
                res_sql = db.update('invoice_details_view', [f'invoice_id = {entrys1[0]}',
                                                                f'counteragent_name = {entrys1[1]}',
                                                                f'date_time = {"'"+date+"'"}',
                                                                f'type_invoice = {"'"+entrys1[3]+"'"}',
                                                                f'status = {"'"+entrys1[4]+"'"}',
                                                                f'type_detail = {"'"+entrys1[5]+"'"}',
                                                                f'quantity = {entrys1[6]}',
                                                                f'responsible_last_name = {"'"+entrys1[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entrys1[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entrys1[9]+"'"}'], 
                                                            [f'invoice_id = {entrys2[0]}',
                                                                f'counteragent_name = {entrys2[1]}',
                                                                f'date_time = {"'"+date2+"'"}',
                                                                f'type_invoice = {"'"+entrys2[3]+"'"}',
                                                                f'status = {"'"+entrys2[4]+"'"}',
                                                                f'type_detail = {"'"+entrys2[5]+"'"}',
                                                                f'quantity = {entrys2[6]}',
                                                                f'responsible_last_name = {"'"+entrys2[7]+"'"}',
                                                                f'responsible_first_name = {"'"+entrys2[8]+"'"}',
                                                                f'responsible_patronymic = {"'"+entrys2[9]+"'"}']) 
                
    elif label_title.cget('text') == 'Сотрудники':
        res_sql = db.update('employee', [f'employee_id = {entrys1[0]}',
                                             f'employee_role = {"'"+entrys1[1]+"'"}',
                                             f'last_name = {"'"+entrys1[2]+"'"}',
                                             f'first_name = {"'"+entrys1[3]+"'"}',
                                             f'patronymic = {"'"+entrys1[4]+"'"}'], 
                                        [f'employee_id = {entrys2[0]}',
                                             f'employee_role = {"'"+entrys2[1]+"'"}',
                                             f'last_name = {"'"+entrys2[2]+"'"}',
                                             f'first_name = {"'"+entrys2[3]+"'"}',
                                             f'patronymic = {"'"+entrys2[4]+"'"}'])
        
    elif label_title.cget('text') == 'Контрагенты':
        res_sql = db.update('counteragent', [f'counteragent_id = {entrys1[0]}',
                                             f'counteragent_name = {"'"+entrys1[1]+"'"}',
                                             f'contact_person = {"'"+entrys1[2]+"'"}',
                                             f'phone_number = {entrys1[3]}',
                                             f'address = {"'"+entrys1[4]+"'"}'], 
                                        [f'counteragent_id = {entrys2[0]}',
                                             f'counteragent_name = {"'"+entrys2[1]+"'"}',
                                             f'contact_person = {"'"+((entrys2[2]).replace("'", '"'))+"'"}',
                                             f'phone_number = {entrys2[3]}',
                                             f'address = {"'"+entrys2[4]+"'"}'])
        
    if res_sql != True:
        messagebox.showerror('Ошибка', res_sql)
    else:
        toplev.destroy()
        messagebox.showinfo('Результат', 'Изменение прошло успешно!')      

def new_window(columns, result):
    topLev = Toplevel()
    topLev.geometry('1200x400')

    new_label = ttk.Label(topLev, text='Результат поиска:', font=("arial", 15), background='#FFFAFA')
    new_label.place(x=5, y=15)

    tree = ttk.Treeview(topLev, columns=columns, show='headings')
    tree.place(x=15, y=50)
    for i in range(len(columns)):
        tree.heading(columns[i], text=columns[i], anchor=W)

    for row in result:
        tree.insert("", END, values=row)
        
#окна интерфейса
def create_select_detail():
    clear_window(window)
    columns = ('Склад', 'Комната', 'Стеллаж', 'Полка', 'ID', 'Тип детали', 'Вес')
    res_select = db.select('details')
    if type(res_select) == str:
        messagebox.showerror('Ошибка доступа', res_select)
        create_main_window(window, login, active_user, password)
    else:
        clear_window(window)
        menu_window(window, 'Детали', columns)

def create_select_invoice():
    clear_window(window)
    columns = ('ID', 'Контрагент', 'Время', 'Тип', 'Статус', "Деталь", "Количество", "Фамилия", "Имя", "Отчество")
    res_select = db.select('invoice')
    if type(res_select) == str:
        messagebox.showerror('Ошибка доступа', res_select)
        create_main_window(window, login, active_user, password)
    else:
        clear_window(window)
        menu_window(window, 'Накладные', columns)

def create_select_employee():
    clear_window(window)
    columns = ('ID', 'Роль', 'Фамилия', 'Имя', 'Отчество')
    res_select = db.select('employee')
    if type(res_select) == str:
        messagebox.showerror('Ошибка доступа', res_select)
        create_main_window(window, login, active_user, password)
    else:
        clear_window(window)
        menu_window(window, 'Сотрудники', columns)

def create_select_counteragent():
    clear_window(window)
    columns = ('ID', 'Название', 'Представитель', 'Телефон', 'Адрес')
    res_select = db.select('counteragent')
    if type(res_select) == str:
        messagebox.showerror('Ошибка выборки', res_select)
        create_main_window(window, login, active_user, password)
    else:
        clear_window(window)
        menu_window(window, 'Контрагенты', columns)






        