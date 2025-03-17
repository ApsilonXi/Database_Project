from tkinter import *
from tkinter import ttk, messagebox
import DB_methods as db
import window as win

# Инициализация главного окна
def start_work():
    '''login, password = entry_name.get(), entry_password.get()'''
    '''active_user = db.create_connection(login, password) '''
    active_user = db.create_connection('ivanov_ii', 'ivanov')
    login = 'ivanov_ii'
    if active_user != None:
        window.destroy()

        main_win = Tk()
        win.create_main_window(main_win, login, active_user)
        main_win.mainloop()
    else:
        messagebox.showerror('Ошибка авторизации', 'Произошла ошибка авторизации пользователя! Проверьте логин и пароль.')
        return 0

# Установка позиции окна
window = Tk()
window.geometry('%dx%d+%d+%d' % (500, 400, (window.winfo_screenwidth()/2) - (500/2), (window.winfo_screenheight()/2) - (400/2)))
window.title("Склад запчастей")
window.configure(background="#FFFAFA")

# Установка глобальных переменных для центровки окна
middle_window_x = 500 / 2
middle_window_y = 400 / 3

title_start = ttk.Label(master=window, text="Войдите в систему", font=("algerian", 20), background="#FFFAFA")
title_start.place(x=middle_window_x, y=100, anchor="center")

title_login = ttk.Label(text="Логин:", font=("algerian", 10), background="#FFFAFA")
title_login.place(x=middle_window_x, y=140, anchor="center")
title_password = ttk.Label(text="Пароль:", font=("algerian", 10), background="#FFFAFA")
title_password.place(x=middle_window_x, y=200, anchor="center")
    
entry_name = ttk.Entry(width=50)
entry_name.place(x=middle_window_x, y=middle_window_y+30, anchor="center")
entry_password = ttk.Entry(width=50, show="*")
entry_password.place(x=middle_window_x, y=middle_window_y+90, anchor="center")

btn_in = ttk.Button(text="Войти", command=start_work)
btn_in.place(x=middle_window_x, y=middle_window_y+160, anchor="center")

window.mainloop()
