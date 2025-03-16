-- Создание роли для Warehouse Clerk (Кладовщик)
CREATE ROLE warehouse_clerk WITH LOGIN PASSWORD 'clerk';
-- Warehouse Clerk может читать и изменять таблицы "Полка", "Стеллаж", "Помещение", "Склад", "Деталь", "Накладная"
GRANT SELECT, INSERT, UPDATE ON TABLE shelf, rack, room, warehouse, details, invoice TO warehouse_clerk;
-- Warehouse Clerk может изменять статус в таблице "Накладная"
GRANT UPDATE (status) ON TABLE invoice TO warehouse_clerk;

-- Создание роли для Warehouse Manager (Менеджер склада)
CREATE ROLE warehouse_manager WITH LOGIN PASSWORD 'manager';
-- Warehouse Manager может управлять "Накладными", привязывать сотрудников и детали
GRANT SELECT, INSERT, UPDATE ON TABLE invoice, invoice_employee, invoice_detail TO warehouse_manager;
-- Warehouse Manager также может просматривать контрагентов и детали
GRANT SELECT ON TABLE counteragent, details TO warehouse_manager;

-- Создание роли для Warehouse Owner (Владелец)
CREATE ROLE warehouse_owner WITH LOGIN PASSWORD 'owner';
-- Warehouse Owner имеет доступ к управлению сотрудниками и контрагентами
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE employee, counteragent TO warehouse_owner;
-- Warehouse Owner также имеет доступ к просмотру складских данных
GRANT SELECT ON TABLE warehouse, room, rack, shelf, details TO warehouse_owner;
