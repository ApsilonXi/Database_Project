-- Создание пользователя с ролью "Кладовщик"
CREATE USER clerk WITH PASSWORD 'clerk';
GRANT warehouse_clerk TO clerk;

-- Создание пользователя с ролью "Менеджер склада"
CREATE USER manager WITH PASSWORD 'manager';
GRANT warehouse_manager TO manager;

-- Создание пользователя с ролью "Владелец склада"
CREATE USER owner WITH PASSWORD 'owner';
GRANT warehouse_owner TO owner;


