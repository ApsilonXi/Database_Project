-- Создание роли для Warehouse Clerk (Кладовщик)
-- Warehouse Clerk может читать и изменять таблицы "Полка", "Стеллаж", "Помещение", "Склад", "Деталь"
-- Warehouse Clerk может изменять статус в таблице "Накладная"
CREATE ROLE warehouse_clerk WITH LOGIN PASSWORD 'clerk';
GRANT SELECT, INSERT, UPDATE ON TABLE shelf, rack, room, warehouse, details TO warehouse_clerk;
GRANT SELECT ON TABLE invoice TO warehouse_clerk;
GRANT UPDATE (status) ON TABLE invoice TO warehouse_clerk;

-- Создание роли для Warehouse Manager (Менеджер склада)
-- Warehouse Manager может управлять "Накладными", привязывать сотрудников и детали
-- Warehouse Manager также может просматривать контрагентов и детали
CREATE ROLE warehouse_manager WITH LOGIN PASSWORD 'manager';
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE invoice, invoice_employee, invoice_detail TO warehouse_manager;
GRANT SELECT ON TABLE counteragent, details TO warehouse_manager;

-- Создание роли для Warehouse Owner (Владелец)
-- Warehouse Owner имеет доступ к управлению сотрудниками и контрагентами
-- Warehouse Owner также имеет доступ к просмотру складских данных
CREATE ROLE warehouse_owner WITH LOGIN PASSWORD 'owner';
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE employee, counteragent TO warehouse_owner;
GRANT SELECT ON TABLE warehouse, room, rack, shelf, details TO warehouse_owner;
