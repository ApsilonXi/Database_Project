from tkinter import *
from tkinter import ttk, messagebox, Menu
import DB_methods

class _App(ttk.Frame):
    def __init__(self, master, active_user, login):
        super().__init__(master)
        self.__active_user = active_user
        self.__login = login
        self.__dbSQL = DB_methods.DataBase(self.__active_user)
        self.place()

        self.__style_btn = ttk.Style()
        self.__style_btn.theme_use("clam")
        self.__style_btn.configure("TButton", font=("algerian", 10, "bold"), foreground="#ACB78E", background="#004524")

        self._middle_window_x = 500/2
        self._middle_window_y = 400/3

        self.master.protocol('WM_DELETE_WINDOW', self.quit_programm)
        self.master.configure(background="#FFFAFA")

    def forget_widget(self, names):
        for widget in names:
            widget.place_forget()

    def create_main_window(self):

        self.master.title("Склад запчастей")
        self.master.geometry('%dx%d+%d+%d' % (1000, 800, (self.master.winfo_screenwidth()/2) - (1000/2), (self.master.winfo_screenheight()/2) - (800/2)))

        self.master.option_add("*tearOff", FALSE)

        find_menu = Menu()
        find_menu.add_command(label="Деталь", command=self.CreateSelectDetail)
        find_menu.add_command(label='Накладная', command=self.CreateSelectInvoice)
        find_menu.add_command(label="Сотрудник", command=self.CreateSelectEmployee)
        find_menu.add_command(label="Контрагент", command=self.CreateSelectCounteragent)

        menu = Menu()
        menu.add_cascade(label="Найти", menu=find_menu)
        menu.add_command(label="Выход", command=self.quit_programm)

        label_title = ttk.Label(text=f'Добро пожаловать, {self.__login}!', font=("arial", 30, "bold"), background="#FFFAFA")
        label_title.place(x=self._middle_window_x+250, y=self._middle_window_y, anchor='center')

        self.main_win_names = [label_title]

        self.master.config(menu=menu)

    def menu_window(self, table, columns, sql_res):

        self.label_title = ttk.Label(text=f'{table}', font=("arial", 30, "bold"), background="#FFFAFA")
        self.label_title.place(x=10, y=15)

        tree = ttk.Treeview(columns=columns, show='headings')
        tree.place(x=30, y=500)

        x_label, y_label, n = 15, 70, 0

        self.entrys_list = []
        for num in range(len(columns)):
            tree.heading(columns[num], text=columns[num], anchor=W)
            tree.column(f"#{num+1}", stretch=NO, width=150)
            new_title = ttk.Label(text=columns[num], font=("arial", 15), background='#FFFAFA')
            new_title.place(x=x_label, y=y_label)
            new_input = ttk.Entry(width=15, background='#FFFAFA')
            new_input.place(x=x_label+120, y=y_label+5)
            self.entrys_list.append(new_input)
            y_label += 40
            n += 1
            if n == 3:
                x_label, y_label, n = 250, 70, 0

        for row in sql_res:
            tree.insert("", END, values=row)

        btn_find = ttk.Button(text='Найти', command=self.FindItem)
        btn_append = ttk.Button(text='Добавить', command=self.InsertItem)
        btn_alter = ttk.Button(text='Изменить', command=self.AlterItem)
        btn_delete = ttk.Button(text='Удалить', command=self.DeleteItem)

        btn_find.place(x=15, y=200)
        btn_append.place(x=135, y=200)
        btn_alter.place(x=255, y=200)
        btn_delete.place(x=375, y=200)

    def quit_programm(self):
        if messagebox.askokcancel('Выход', 'Действительно хотите закрыть окно?'):
            DB_methods.CONNECTION(None, None).CloseConnection(self.__active_user)
            quit()

    def FindItem(self):
        entrys = []
        for i in self.entrys_list:
            entrys.append(i.get())

        match self.label_title:
            case 'Детали':
                self.__dbSQL.SELECT('details')
            case 'Накладные':
                self.__dbSQL.SELECT('invoice')
            case 'Сотрудники':
                self.__dbSQL.SELECR('employee')
            case 'Контрагенты':
                self.__dbSQL.SELECT('counteragent')


    def InsertItem(self):
        pass

    def AlterItem(self):
        pass

    def DeleteItem(self):
        pass
        
    def CreateSelectDetail(self):
        colmn = ('id', 'ПолкаID', 'Вес', 'Тип детали')
        res_select = self.__dbSQL.SELECT('details')
        if type(res_select) == str:
            messagebox.showerror('Ошибка доступа', res_select)
            return 0
        else:
            self.forget_widget(self.main_win_names)
            self.menu_window('Детали', colmn, res_select)

    def CreateSelectInvoice(self):
        colmn = ('id', 'Контрагент', 'Время', 'Тип накладной', 'Статус')
        res_select = self.__dbSQL.SELECT('protected.invoice')
        if type(res_select) == str:
            messagebox.showerror('Ошибка доступа', res_select)
            return 0
        else:
            self.forget_widget(self.main_win_names)
            self.menu_window('Накладные', colmn, res_select)

    def CreateSelectEmployee(self):
        colmn = ('id', 'Роль', 'Фамилия', 'Имя', 'Отчество')
        res_select = self.__dbSQL.SELECT('private.employee')
        if type(res_select) == str:
            messagebox.showerror('Ошибка доступа', res_select)
            return 0
        else:
            self.forget_widget(self.main_win_names)
            self.menu_window('Сотрудники', colmn, res_select)


    def CreateSelectCounteragent(self):
        colmn = ('id', 'Название', 'Контактное лицо', 'Телефон', 'Адрес')
        res_select = self.__dbSQL.SELECT('private.counteragent')
        if type(res_select) == str:
            messagebox.showerror('Ошибка выборки', res_select)
            return 0
        else:
            self.forget_widget(self.main_win_names)
            self.menu_window('Контрагенты', colmn, res_select)






