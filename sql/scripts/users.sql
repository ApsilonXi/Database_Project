-- Создание пользователя с ролью "Кладовщик"
CREATE USER ivanov_ii WITH PASSWORD 'ivanov';
GRANT warehouse_clerk TO ivanov_ii;

-- Создание пользователя с ролью "Менеджер склада"
CREATE USER volkov_aa WITH PASSWORD 'volkov';
GRANT warehouse_manager TO volkov_aa;

-- Создание пользователя с ролью "Владелец склада"
CREATE USER sidorov_av WITH PASSWORD 'sidorov';
GRANT warehouse_owner TO sidorov_av;


