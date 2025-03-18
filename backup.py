import os
import subprocess
from datetime import datetime

def backup_database(db_name, user, port, backup_dir):
    # Генерация имени файла для резервной копии
    backup_file = os.path.join(backup_dir, f"{db_name}_backup_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.sql")

    # Проверка, существует ли директория для резервных копий
    if not os.path.exists(backup_dir):
        print(f"Ошибка: Директория для резервных копий не существует: {backup_dir}")
        return

    # Путь к утилите pg_dump (проверьте путь к вашему pg_dump)
    pg_dump_path = r'C:\Program Files\PostgreSQL\17\bin\pg_dump.exe'

    command = [
    "C:\\Program Files\\PostgreSQL\\17\\bin\\pg_dump.exe",
    "-U", "sidorov_av",
    "-h", "127.0.0.1",
    "-p", "5432",
    "-F", "c",
    "-b", "-v",
    "--no-owner",
    "-f", "D:\\GitHub\\Database_Project\\sql\\backup\\Warehouse_DB_backup_2025-03-18_03-29-39.sql",
    "Warehouse_DB"
    ]

    try:
        # Запуск команды резервного копирования с записью вывода в файл
        result = subprocess.run(command, check=True, env={"PGPASSWORD": "sidorov"})
        print(f"Резервная копия успешно создана: {backup_file}")
        print(f"Вывод pg_dump: {result.stdout}")
    except subprocess.CalledProcessError as e:
        print(f"Ошибка при создании резервной копии: {e}")
        print(f"Вывод stderr: {e.stderr}") # Сохраним подробный вывод ошибки в файл

# Укажите абсолютный путь для директории резервных копий
backup_dir = r'D:\GitHub\Database_Project\sql\backup'  # Убедитесь, что путь существует
backup_database('Warehouse_DB', 'sidorov_av', 5432, backup_dir)
