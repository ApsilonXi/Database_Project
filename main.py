from tkinter import *
from tkinter import ttk, messagebox
import DB_methods
from window import _App

class __StartWindow(ttk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.place()

        self.__style_btn = ttk.Style()
        self.__style_btn.theme_use("clam")
        self.__style_btn.configure("TButton", font=("algerian", 10, "bold"), foreground="#ACB78E", background="#004524")

        self._middle_window_x = 500/2
        self._middle_window_y = 400/3

    def start_work(self):
        login, password = self.entry_name.get(), self.entry_password.get()
        active_user = DB_methods.CONNECTION(login, password).CreateConnection()   
        if active_user != 0:
            self.master.destroy()

            main_win = Tk()
            main = _App(main_win, active_user, login)
            main.create_main_window()
            main_win.mainloop()
        else:
            messagebox.showerror('Ошибка авторизации', 'Такого пользователя не существует! Попробуйте ещё раз.')
            return 0

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
app = __StartWindow(window)
app.start_window()
app.mainloop()