from tkinter import *
from tkinter import ttk, messagebox, Menu
import DB_methods as db
from datetime import datetime

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
    
    for fmt in date_formats:
        try:
            date_obj = datetime.strptime(date_str, fmt)
            return date_obj.strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            continue
    return False

def create_main_window(win, log, user):
    global active_user, window, login
    window = win
    active_user = user
    login = log

    clear_window(window)

    window.title("Склад запчастей")
    window.geometry('%dx%d+%d+%d' % (1000, 800, (window.winfo_screenwidth() / 2) - (1000 / 2), (window.winfo_screenheight() / 2) - (800 / 2)))

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

    window.protocol("WM_DELETE_WINDOW", quit_programm)

def menu_window(window, table, columns):
    label_title = ttk.Label(window, text=f'{table}', font=("arial", 30, "bold"), background="#FFFAFA")
    label_title.place(x=10, y=15)

    x_label, y_label, n = 15, 70, 0
    ENTRYS_LIST = []
    ENTRYS_LIST_titles = []

    window.option_add("*tearOff", FALSE)
    menu = Menu()
    menu.add_cascade(label="Назад", command=lambda: create_main_window(window, login, active_user))
    menu.add_command(label="Выход", command=quit_programm)
    window.config(menu=menu)

    for num in range(len(columns)):
        new_title = ttk.Label(window, text=columns[num], font=("arial", 15), background='#FFFAFA')
        new_title.place(x=x_label, y=y_label)
        new_input = ttk.Entry(window, width=15, background='#FFFAFA')
        new_input.place(x=x_label + 120, y=y_label + 5)
        ENTRYS_LIST.append(new_input)
        ENTRYS_LIST_titles.append(columns[num])
        y_label += 40
        n += 1
        if n == 3:
            x_label, y_label, n = 250, 70, 0

    btn_find = ttk.Button(window, text='Найти', command=lambda: find_item(ENTRYS_LIST, label_title))
    btn_insert = ttk.Button(window, text='Добавить', command=lambda: insert_item(ENTRYS_LIST, label_title))
    btn_update = ttk.Button(window, text='Изменить', command=lambda: where_update(ENTRYS_LIST_titles, ENTRYS_LIST, label_title))
    btn_delete = ttk.Button(window, text='Удалить', command=lambda: delete_item(ENTRYS_LIST, label_title))

    btn_find.place(x=15, y=200)
    btn_insert.place(x=135, y=200)
    btn_update.place(x=255, y=200)
    btn_delete.place(x=375, y=200)

    window.protocol("WM_DELETE_WINDOW", quit_programm)

def find_item(ENTRYS_LIST, label_title):
    entries = [entry.get() for entry in ENTRYS_LIST]
    if label_title.cget('text') == 'Детали':
        res_sql = db.select('details', '*', [f'detail_id = {entries[0]}',
                                             f'shelfID = {entries[1]}',
                                             f'weight = {entries[2]}',
                                             f'type_detail = {entries[3]}'])
        if type(res_sql) == str:
            messagebox.showerror('Нет результата', res_sql)
        elif len(res_sql) == 0:
            messagebox.showerror('Результат запроса', 'По вашему запросу ничего не найдено')
        else:
            new_window(('ID', 'Полка', 'Вес', 'Тип'), res_sql)

    if label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entries[2])
        if (date == False) and (entries[2] != ""):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif entries[2] == "":
            res_sql = db.select('invoice', '*', [f'invoice_id = {entries[0]}',
                                                f'counteragentID = {entries[1]}',
                                                f'date_time = {entries[2]}',
                                                f'type_invoice = {entries[3]}',
                                                f'status = {entries[4]}'])
        else:
            res_sql = db.select('invoice', '*', [f'invoice_id = {entries[0]}',
                                                f'counteragentID = {entries[1]}',
                                                f'date_time = {"'"+date+"'"}',
                                                f'type_invoice = {entries[3]}',
                                                f'status = {entries[4]}'])
        if type(res_sql) == str:
            messagebox.showerror('Нет результата', res_sql)
        elif len(res_sql) == 0:
            messagebox.showerror('Результат запроса', 'По вашему запросу ничего не найдено')
        else:
            new_window(('ID', 'ID агента', 'Время', 'Тип', 'Статус'), res_sql)

def insert_item(ENTRYS_LIST, label_title):
    entries = [entry.get() for entry in ENTRYS_LIST]
    if label_title.cget('text') == 'Детали':
        res_sql = db.insert('details', [f'detail_id = {entries[0]}',
                                             f'shelfID = {entries[1]}',
                                             f'weight = {entries[2]}',
                                             f'type_detail = {entries[3]}'])
        if res_sql != True:
            messagebox.showerror('Ошибка', res_sql)
        else:
            messagebox.showinfo('Результат', 'Добавление прошло успешно!')

    if label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entries[2])
        if (date == False) and (entries[2] != ""):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif entries[2] == "":
            res_sql = db.insert('invoice', [f'invoice_id = {entries[0]}',
                                                f'counteragentID = {entries[1]}',
                                                f'date_time = {entries[2]}',
                                                f'type_invoice = {entries[3]}',
                                                f'status = {entries[4]}'])
        else:
            res_sql = db.insert('invoice', [f'invoice_id = {entries[0]}',
                                                f'counteragentID = {entries[1]}',
                                                f'date_time = {date}',
                                                f'type_invoice = {entries[3]}',
                                                f'status = {entries[4]}'])
        if res_sql != True:
            messagebox.showerror('Ошибка', res_sql)
        else:
            messagebox.showinfo('Результат', 'Добавление прошло успешно!')

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
    toplev.geometry('700x700')
    toplev.title('Введите условия')
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
            x_label, y_label, n = 250, 70, 0
    btn_update = ttk.Button(master=toplev, text='Ввести', command=lambda: update_item(ENTRYS_LIST, ENTRYS_LIST_wheres, label_title))
    btn_update.place(x=15, y=200)

def update_item(ENTRYS_LIST, ENTRYS_LIST_wheres, label_title):
    entrys1 = [entry.get() for entry in ENTRYS_LIST]
    entrys2 = [entry.get() for entry in ENTRYS_LIST_wheres]
    if label_title.cget('text') == 'Детали':
        res_sql = db.update('details', [f'detail_id = {entrys1[0]}',
                                            f'shelfID = {entrys1[1]}',
                                            f'weight = {entrys1[2]}',
                                            f'type_detail = {entrys1[3]}'], 
                                            [f'detail_id = {entrys2[0]}',
                                            f'shelfID = {entrys2[1]}',
                                            f'weight = {entrys2[2]}',
                                            f'type_detail = {entrys2[3]}'])
        if res_sql != True:
            messagebox.showerror('Ошибка', res_sql)
        else:
            toplev.destroy()
            messagebox.showinfo('Результат', 'Изменение прошло успешно!')

    if label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entrys1[2])
        date2 = convert_to_standard_format(entrys2[2])
        if (date == False) and ((entrys1[2] != "") or (entrys2[2] != "")):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif (entrys1[2] == "") and (entrys2[2] == ""):
            res_sql = db.update('invoice', [f'invoice_id = {entrys1[0]}',
                                                f'counteragentID = {entrys1[1]}',
                                                f'date_time = {entrys1[2]}',
                                                f'type_invoice = {entrys1[3]}',
                                                f'status = {entrys1[4]}'], 
                                            [f'invoice_id = {entrys2[0]}',
                                                f'counteragentID = {entrys2[1]}',
                                                f'date_time = {entrys2[2]}',
                                                f'type_invoice = {entrys2[3]}',
                                                f'status = {entrys2[4]}'])
            
        else:
            if (entrys1[2] != "") and ((entrys2[2] == "")):
                res_sql = db.update('invoice', [f'invoice_id = {entrys1[0]}',
                                                    f'counteragentID = {entrys1[1]}',
                                                    f'date_time = {"'"+date+"'"}',
                                                    f'type_invoice = {entrys1[3]}',
                                                    f'status = {entrys1[4]}'], 
                                                [f'invoice_id = {entrys2[0]}',
                                                    f'counteragentID = {entrys2[1]}',
                                                    f'date_time = {entrys2[2]}',
                                                    f'type_invoice = {entrys2[3]}',
                                                    f'status = {entrys2[4]}'])
            if (entrys1[2] == "") and ((entrys2[2] != "")):
                res_sql = db.update('invoice', [f'invoice_id = {entrys1[0]}',
                                                    f'counteragentID = {entrys1[1]}',
                                                    f'date_time = {entrys1[2]}',
                                                    f'type_invoice = {entrys1[3]}',
                                                    f'status = {entrys1[4]}'], 
                                                [f'invoice_id = {entrys2[0]}',
                                                    f'counteragentID = {entrys2[1]}',
                                                    f'date_time = {"'"+date2+"'"}',
                                                    f'type_invoice = {entrys2[3]}',
                                                    f'status = {entrys2[4]}'])        
        if res_sql != True:
            messagebox.showerror('Ошибка', res_sql)
        else:
            toplev.destroy()
            messagebox.showinfo('Результат', 'Изменение прошло успешно!')


def delete_item(ENTRYS_LIST, label_title):
    entries = [entry.get() for entry in ENTRYS_LIST]
    if label_title.cget('text') == 'Детали':
        res_sql = db.delete('details', [f'detail_id = {entries[0]}',
                                            f'shelfID = {entries[1]}',
                                            f'weight = {entries[2]}',
                                            f'type_detail = {entries[3]}'])
        if res_sql != True:
            messagebox.showerror('Ошибка', res_sql)
        else:
            messagebox.showinfo('Результат', 'Удаление прошло успешно!')

    if label_title.cget('text') == 'Накладные':
        date = convert_to_standard_format(entries[2])
        if (date == False) and (entries[2] != ""):
            messagebox.showerror('Неверный формат', "Неверный формат даты!")
        elif entries[2] == "":
            res_sql = db.delete('invoice', [f'invoice_id = {entries[0]}',
                                                f'counteragentID = {entries[1]}',
                                                f'date_time = {entries[2]}',
                                                f'type_invoice = {entries[3]}',
                                                f'status = {entries[4]}'])
        else:
            res_sql = db.delete('invoice', [f'invoice_id = {entries[0]}',
                                                f'counteragentID = {entries[1]}',
                                                f'date_time = {date}',
                                                f'type_invoice = {entries[3]}',
                                                f'status = {entries[4]}'])
        if res_sql != True:
            messagebox.showerror('Ошибка', res_sql)
        else:
            messagebox.showinfo('Результат', 'Удаление прошло успешно!')

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



#окна (не сам поиск)
def create_select_detail():
    clear_window(window)
    columns = ('ID', 'ПолкаID', 'Вес', 'Тип детали')
    res_select = db.select('details')
    if type(res_select) == str:
        messagebox.showerror('Ошибка доступа', res_select)
        create_main_window(window, login, active_user)
    else:
        clear_window(window)
        menu_window(window, 'Детали', columns)

def create_select_invoice():
    clear_window(window)
    columns = ('ID', 'Контрагент', 'Время', 'Тип', 'Статус')
    res_select = db.select('invoice')
    if type(res_select) == str:
        messagebox.showerror('Ошибка доступа', res_select)
        create_main_window(window, login, active_user)
    else:
        clear_window(window)
        menu_window(window, 'Накладные', columns)

def create_select_employee():
    clear_window(window)
    columns = ('ID', 'Роль', 'Фамилия', 'Имя', 'Отчество')
    res_select = db.select('employee')
    if type(res_select) == str:
        messagebox.showerror('Ошибка доступа', res_select)
        create_main_window(window, login, active_user)
    else:
        clear_window(window)
        menu_window(window, 'Сотрудники', columns)

def create_select_counteragent():
    clear_window(window)
    columns = ('ID', 'Название', 'Контактное лицо', 'Телефон', 'Адрес')
    res_select = db.select('counteragent')
    if type(res_select) == str:
        messagebox.showerror('Ошибка выборки', res_select)
        create_main_window(window, login, active_user)
    else:
        clear_window(window)
        menu_window(window, 'Контрагенты', columns)
        