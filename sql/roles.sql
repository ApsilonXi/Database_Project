-- Создание роли для Warehouse Clerk (Кладовщик)
-- Warehouse Clerk может читать и изменять таблицы "Полка", "Стеллаж", "Помещение", "Склад", "Деталь"
-- Warehouse Clerk может изменять статус в таблице "Накладная"
CREATE ROLE warehouse_clerk WITH LOGIN PASSWORD 'clerk';
GRANT SELECT, INSERT, UPDATE ON TABLE shelf, rack, room, warehouse, details TO warehouse_clerk;
GRANT SELECT ON TABLE invoice TO warehouse_clerk;
GRANT UPDATE (status) ON TABLE invoice TO warehouse_clerk;
GRANT USAGE, SELECT ON SEQUENCE invoice_log_log_id_seq TO warehouse_clerk;
GRANT INSERT, SELECT ON TABLE invoice_log TO warehouse_clerk;


-- Создание роли для Warehouse Manager (Менеджер склада)
-- Warehouse Manager может управлять "Накладными", привязывать сотрудников и детали
-- Warehouse Manager также может просматривать контрагентов и детали
CREATE ROLE warehouse_manager WITH LOGIN PASSWORD 'manager';
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE invoice, invoice_employee, invoice_detail TO warehouse_manager;
GRANT SELECT ON TABLE counteragent, details TO warehouse_manager;
GRANT USAGE, SELECT ON SEQUENCE invoice_log_log_id_seq TO warehouse_manager;
GRANT INSERT, SELECT ON TABLE invoice_log TO warehouse_manager;
GRANT USAGE, SELECT ON SEQUENCE invoice_invoice_id_seq TO warehouse_manager;
GRANT USAGE, SELECT ON SEQUENCE employee_employee_id_seq TO warehouse_manager;
GRANT USAGE, SELECT ON SEQUENCE invoice_detail_invoiceid_seq TO warehouse_manager;

-- Создание роли для Warehouse Owner (Владелец)
-- Warehouse Owner имеет доступ к управлению сотрудниками и контрагентами
-- Warehouse Owner также имеет доступ к просмотру складских данных
CREATE ROLE warehouse_owner WITH LOGIN PASSWORD 'owner';
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE employee, counteragent TO warehouse_owner;
GRANT SELECT ON TABLE warehouse, room, rack, shelf, details TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE employee_employee_id_seq TO warehouse_owner;
GRANT CONNECT ON DATABASE "Warehouse_DB" TO warehouse_owner;
GRANT USAGE ON SCHEMA public TO warehouse_owner;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO warehouse_owner;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO warehouse_owner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO warehouse_owner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.counteragent_counteragent_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.details_detail_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.details_shelfid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_counteragentid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_detail_detailid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_detail_invoiceid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_employee_granted_access_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_employee_invoiceid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_employee_responsible_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_invoice_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.rack_rack_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.rack_roomid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.room_room_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.room_warehouseid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.shelf_rackid_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.shelf_shelf_id_seq TO warehouse_owner;
GRANT USAGE, SELECT ON SEQUENCE public.warehouse_warehouse_id_seq TO warehouse_owner;





