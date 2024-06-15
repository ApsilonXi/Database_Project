from tkinter import ttk, Tk, messagebox
import main
from config import host, db_name

class App(ttk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.place()

        self.__style_btn = ttk.Style()
        self.__style_btn.theme_use("clam")
        self.__style_btn.configure("TButton", font=("algerian", 10, "bold"), foreground="#ACB78E", background="#004524")

        self._middle_window_x = 500/2
        self._middle_window_y = 400/3

        self.master.protocol('WM_DELETE_WINDOW', self.quit_programm)

    def create_main_window(self):
        self.master.destroy()

        main_window = Tk()
        main_window.title("Склад запчастей")
        main_window.geometry('%dx%d+%d+%d' % (1000, 800, (main_window.winfo_screenwidth()/2) - (1000/2), (main_window.winfo_screenheight()/2) - (800/2)))

        self.btn_exit = ttk.Button(text="Выход", command=self.quit_programm)
        self.btn_exit.place(x=self._middle_window_x, y=self._middle_window_y+180, anchor="center")

        main_window.mainloop()

    def start_work(self):
        self.CreateConnection()
        self.create_main_window()  

    def CreateConnection(self):
        global active_user
        try:
            active_user = main.DataBase(host, db_name, self.entry_name.get(), self.entry_password.get())
        except:
            messagebox.showerror("Ошибка авторизации", "Такого пользователя не существует")
            return 0
        
    def quit_programm(self):
        if messagebox.askokcancel('Выход', 'Действительно хотите закрыть окно?'):
            if 'active_user' in globals():
                active_user.CloseConnection()
            quit()

    def start_window(self):
        self.__title_start = ttk.Label(text="Войдите в систему", font=("algerian", 20), background="#FFFAFA")
        self.__title_start.place(x=self._middle_window_x, y=100, anchor="center")

        self.__title_login = ttk.Label(text="Логин:", font=("algerian", 10), background="#FFFAFA")
        self.__title_login.place(x=self._middle_window_x, y=140, anchor="center")
        self.__title_password = ttk.Label(text="Пароль:", font=("algerian", 10), background="#FFFAFA")
        self.__title_password.place(x=self._middle_window_x, y=200, anchor="center")
        
        self.entry_name = ttk.Entry(width=50)
        self.entry_name.place(x=self._middle_window_x, y=self._middle_window_y+30, anchor="center")
        self.entry_password = ttk.Entry(width=50, show="*")
        self.entry_password.place(x=self._middle_window_x, y=self._middle_window_y+90, anchor="center")

        self.__btn_in = ttk.Button(text="Войти", command=self.start_work)
        self.__btn_in.place(x=self._middle_window_x, y=self._middle_window_y+160, anchor="center")



'''________main________'''

window = Tk()
window.geometry('%dx%d+%d+%d' % (500, 400, (window.winfo_screenwidth()/2) - (500/2), (window.winfo_screenheight()/2) - (400/2)))
window.title("Склад запчастей")
window.configure(background="#FFFAFA")
app = App(window)
app.start_window()
app.mainloop()