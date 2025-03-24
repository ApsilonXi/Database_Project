CREATE OR REPLACE FUNCTION fill_invoice_employee() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (NEW.invoice_id, 1, 2, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_fill_invoice_employee
AFTER INSERT ON invoice
FOR EACH ROW
EXECUTE FUNCTION fill_invoice_employee();


CREATE OR REPLACE FUNCTION fill_invoice_detail() 
RETURNS TRIGGER AS $$ 
BEGIN 
    DECLARE
        invoice_type boolean;
        type_detail text;
    BEGIN
        SELECT type_invoice INTO invoice_type
        FROM invoice
        WHERE invoice_id = NEW.invoice_id;

        INSERT INTO invoice_detail (invoiceID, detailID, quantity)
        VALUES (NEW.invoice_id, 
                (SELECT detail_id FROM details WHERE type_detail = type_detail LIMIT 1), 
                10); 

        IF invoice_type = true THEN
            UPDATE details
            SET stock_quantity = stock_quantity + 10  
            WHERE detail_id = (SELECT detail_id FROM details WHERE type_detail = type_detail LIMIT 1);

        ELSE
            UPDATE details
            SET stock_quantity = stock_quantity - 10 
            WHERE detail_id = (SELECT detail_id FROM details WHERE type_detail = type_detail LIMIT 1);

        END IF;
    END;
    
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_fill_invoice_detail
AFTER INSERT ON invoice
FOR EACH ROW
EXECUTE FUNCTION fill_invoice_detail();

CREATE OR REPLACE FUNCTION add_default_room() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO room (warehouseID, room_number) VALUES (NEW.warehouse_id, 1);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_add_default_room
AFTER INSERT ON warehouse
FOR EACH ROW
EXECUTE FUNCTION add_default_room();

CREATE OR REPLACE FUNCTION add_default_rack() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO rack (roomID, rack_number) VALUES (NEW.room_id, 1);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_add_default_rack
AFTER INSERT ON room
FOR EACH ROW
EXECUTE FUNCTION add_default_rack();

CREATE OR REPLACE FUNCTION add_default_shelf() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO shelf (rackID, shelf_number) VALUES (NEW.rack_id, 1);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_add_default_shelf
AFTER INSERT ON rack
FOR EACH ROW
EXECUTE FUNCTION add_default_shelf();

CREATE OR REPLACE FUNCTION delete_related_data() 
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM room WHERE warehouseID = OLD.warehouse_id;
    DELETE FROM rack WHERE roomID IN (SELECT room_id FROM room WHERE warehouseID = OLD.warehouse_id);
    DELETE FROM shelf WHERE rackID IN (SELECT rack_id FROM rack WHERE roomID IN (SELECT room_id FROM room WHERE warehouseID = OLD.warehouse_id));
    DELETE FROM details WHERE shelfID IN (SELECT shelf_id FROM shelf WHERE rackID IN (SELECT rack_id FROM rack WHERE roomID IN (SELECT room_id FROM room WHERE warehouseID = OLD.warehouse_id)));
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_delete_related_data
BEFORE DELETE ON warehouse
FOR EACH ROW
EXECUTE FUNCTION delete_related_data();

CREATE OR REPLACE FUNCTION add_default_detail() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO details (shelfID, weight, type_detail) VALUES (NEW.shelf_id, 5.0, 'Новая деталь');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_add_default_detail
AFTER INSERT ON shelf
FOR EACH ROW
EXECUTE FUNCTION add_default_detail();


CREATE OR REPLACE FUNCTION update_shelfID_in_details() 
RETURNS TRIGGER AS $$
BEGIN
    UPDATE details SET shelfID = NEW.shelf_id WHERE shelfID = OLD.shelf_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_shelfID_in_details
AFTER UPDATE ON shelf
FOR EACH ROW
EXECUTE FUNCTION update_shelfID_in_details();

-- Триггер для вставки новой записи в таблицу invoice и invoice_detail
CREATE OR REPLACE FUNCTION insert_invoice_details_view() 
RETURNS TRIGGER AS $$
BEGIN
    -- Вставка данных в invoice
    INSERT INTO invoice (invoice_id, counteragentID, date_time, type_invoice, status)
    VALUES (NEW.invoice_id, NEW.counteragentID, NEW.date_time, NEW.type_invoice, NEW.status);

    -- Вставка данных в invoice_detail
    INSERT INTO invoice_detail (invoiceID, detailID, quantity)
    VALUES (NEW.invoice_id, NEW.detailID, NEW.quantity);

    -- Вставка данных в invoice_employee
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (NEW.invoice_id, NEW.responsible, NEW.granted_access, NEW.when_granted);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Применение триггера для таблицы invoice_detail
CREATE TRIGGER trg_insert_invoice_details
AFTER INSERT ON invoice_detail
FOR EACH ROW
EXECUTE FUNCTION insert_invoice_details_view();


-- Триггер для удаления записи из таблицы invoice, invoice_detail и invoice_employee
CREATE OR REPLACE FUNCTION delete_invoice_details_view() 
RETURNS TRIGGER AS $$
BEGIN
    -- Удаление записи из invoice
    DELETE FROM invoice
    WHERE invoice_id = OLD.invoice_id;

    -- Удаление записи из invoice_detail
    DELETE FROM invoice_detail
    WHERE invoiceID = OLD.invoice_id;

    -- Удаление записи из invoice_employee
    DELETE FROM invoice_employee
    WHERE invoiceID = OLD.invoice_id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Применение триггера для таблицы invoice
CREATE TRIGGER trg_delete_invoice_details
AFTER DELETE ON invoice
FOR EACH ROW
EXECUTE FUNCTION delete_invoice_details_view();

CREATE OR REPLACE FUNCTION delete_user(username TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE format('DROP ROLE %I', username);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION insert_into_warehouse_details()
RETURNS TRIGGER AS $$
BEGIN
    -- Добавляем запись в таблицу room, если комната с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM room WHERE room_number = NEW.room_number) THEN
        INSERT INTO room (room_number) VALUES (NEW.room_number) RETURNING room_id INTO NEW.room_id;
    ELSE
        SELECT room_id INTO NEW.room_id FROM room WHERE room_number = NEW.room_number;
    END IF;

    -- Добавляем запись в таблицу rack, если стеллаж с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM rack WHERE rack_number = NEW.rack_number) THEN
        INSERT INTO rack (rack_number) VALUES (NEW.rack_number) RETURNING rack_id INTO NEW.rack_id;
    ELSE
        SELECT rack_id INTO NEW.rack_id FROM rack WHERE rack_number = NEW.rack_number;
    END IF;

    -- Добавляем запись в таблицу shelf, если полка с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM shelf WHERE shelf_number = NEW.shelf_number) THEN
        INSERT INTO shelf (shelf_number) VALUES (NEW.shelf_number) RETURNING shelf_id INTO NEW.shelf_id;
    ELSE
        SELECT shelf_id INTO NEW.shelf_id FROM shelf WHERE shelf_number = NEW.shelf_number;
    END IF;

    -- Добавляем деталь в таблицу details
    INSERT INTO details (weight, type_detail) VALUES (NEW.weight, NEW.type_detail);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_insert_warehouse_details
INSTEAD OF INSERT ON warehouse_details_view
FOR EACH ROW
EXECUTE FUNCTION insert_into_warehouse_details();

CREATE OR REPLACE FUNCTION update_warehouse_details()
RETURNS TRIGGER AS $$
DECLARE
    warehouse_id integer;
    room_id integer;
    rack_id integer;
    shelf_id integer;
BEGIN
    -- Получаем warehouse_id на основе warehouse_number из представления
    SELECT w.warehouse_id INTO warehouse_id
    FROM warehouse w
    WHERE w.warehouse_number = OLD.warehouse_number;
    
    -- Получаем room_id на основе warehouse_id и room_number
    SELECT r.room_id INTO room_id
    FROM room r
    WHERE r.warehouseID = warehouse_id AND r.room_number = OLD.room_number;
    
    -- Получаем rack_id на основе room_id и rack_number
    SELECT ra.rack_id INTO rack_id
    FROM rack ra
    WHERE ra.roomID = room_id AND ra.rack_number = OLD.rack_number;
    
    -- Получаем shelf_id на основе rack_id и shelf_number
    SELECT s.shelf_id INTO shelf_id
    FROM shelf s
    WHERE s.rackID = rack_id AND s.shelf_number = OLD.shelf_number;

    -- Обновляем запись в таблице details
    UPDATE details
    SET type_detail = NEW.type_detail, weight = NEW.weight
    WHERE shelfID = shelf_id AND detail_id = OLD.detail_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_warehouse_details_trigger
INSTEAD OF UPDATE ON warehouse_details_view
FOR EACH ROW
EXECUTE FUNCTION update_warehouse_details();

CREATE OR REPLACE FUNCTION delete_warehouse_details()
RETURNS TRIGGER AS $$
DECLARE
    warehouse_id_value integer;  -- Идентификатор склада
    room_id_value integer;       -- Идентификатор комнаты
    rack_id_value integer;       -- Идентификатор стеллажа
    shelf_id_value integer;      -- Идентификатор полки
BEGIN
    -- Получаем warehouse_id на основе warehouse_number
    SELECT w.warehouse_id INTO warehouse_id_value
    FROM warehouse w
    WHERE w.warehouse_number = OLD.warehouse_number;

    -- Получаем room_id на основе warehouse_id и room_number
    SELECT r.room_id INTO room_id_value
    FROM room r
    WHERE r.warehouseID = warehouse_id_value AND r.room_number = OLD.room_number;

    -- Получаем rack_id на основе room_id и rack_number
    SELECT ra.rack_id INTO rack_id_value
    FROM rack ra
    WHERE ra.roomID = room_id_value AND ra.rack_number = OLD.rack_number;

    -- Получаем shelf_id на основе rack_id и shelf_number
    SELECT s.shelf_id INTO shelf_id_value
    FROM shelf s
    WHERE s.rackID = rack_id_value AND s.shelf_number = OLD.shelf_number;

    -- Удаляем запись из таблицы details
    DELETE FROM details WHERE detail_id = OLD.detail_id;

    -- Удаляем запись из таблицы shelf, если на ней больше нет деталей
    DELETE FROM shelf 
    WHERE shelf.shelf_id = shelf_id_value
      AND NOT EXISTS (SELECT 1 FROM details WHERE details.shelfID = shelf.shelf_id);

    -- Удаляем запись из таблицы rack, если на стеллаже больше нет полок
    DELETE FROM rack 
    WHERE rack.rack_id = rack_id_value 
      AND NOT EXISTS (SELECT 1 FROM shelf WHERE shelf.rackID = rack.rack_id);

    -- Удаляем запись из таблицы room, если в комнате больше нет стеллажей
    DELETE FROM room 
    WHERE room.room_id = room_id_value 
      AND NOT EXISTS (SELECT 1 FROM rack WHERE rack.roomID = room.room_id);

    -- Удаляем запись из таблицы warehouse, если на складе больше нет комнат
    DELETE FROM warehouse 
    WHERE warehouse.warehouse_id = warehouse_id_value 
      AND NOT EXISTS (SELECT 1 FROM room WHERE room.warehouseID = warehouse.warehouse_id);

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;



CREATE or replace TRIGGER delete_warehouse_details_trigger
INSTEAD OF DELETE ON warehouse_details_view
FOR EACH ROW
EXECUTE FUNCTION delete_warehouse_details();


-- Создание триггера для проверки изменений только поля status
CREATE OR REPLACE FUNCTION update_invoice_status_only()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка, что только статус изменен
    IF NEW.status IS DISTINCT FROM OLD.status AND
       (NEW.date_time IS DISTINCT FROM OLD.date_time OR 
        NEW.type_invoice IS DISTINCT FROM OLD.type_invoice) THEN
        RAISE EXCEPTION 'You can only update the "status" field.';
    END IF;

    -- Обновление только статуса
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        UPDATE invoice
        SET status = NEW.status
        WHERE invoice_id = OLD.invoice_id;
    END IF;

    -- Возвращаем новое значение для выполнения операции
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера
CREATE TRIGGER update_invoice_status_trigger
INSTEAD OF UPDATE ON invoice_details_view
FOR EACH ROW
EXECUTE FUNCTION update_invoice_status_only();

CREATE OR REPLACE FUNCTION log_warehouse_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('warehouse', 'INSERT', NEW.warehouse_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('warehouse', 'UPDATE', OLD.warehouse_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('warehouse', 'DELETE', OLD.warehouse_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы warehouse
CREATE TRIGGER warehouse_changes
AFTER INSERT OR UPDATE OR DELETE ON warehouse
FOR EACH ROW EXECUTE FUNCTION log_warehouse_changes();

CREATE OR REPLACE FUNCTION log_room_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('room', 'INSERT', NEW.room_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('room', 'UPDATE', OLD.room_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('room', 'DELETE', OLD.room_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы room
CREATE TRIGGER room_changes
AFTER INSERT OR UPDATE OR DELETE ON room
FOR EACH ROW EXECUTE FUNCTION log_room_changes();

CREATE OR REPLACE FUNCTION log_rack_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('rack', 'INSERT', NEW.rack_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('rack', 'UPDATE', OLD.rack_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('rack', 'DELETE', OLD.rack_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы rack
CREATE TRIGGER rack_changes
AFTER INSERT OR UPDATE OR DELETE ON rack
FOR EACH ROW EXECUTE FUNCTION log_rack_changes();

CREATE OR REPLACE FUNCTION log_shelf_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('shelf', 'INSERT', NEW.shelf_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('shelf', 'UPDATE', OLD.shelf_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('shelf', 'DELETE', OLD.shelf_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы shelf
CREATE TRIGGER shelf_changes
AFTER INSERT OR UPDATE OR DELETE ON shelf
FOR EACH ROW EXECUTE FUNCTION log_shelf_changes();

CREATE OR REPLACE FUNCTION log_details_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('details', 'INSERT', NEW.detail_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('details', 'UPDATE', OLD.detail_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('details', 'DELETE', OLD.detail_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы details
CREATE TRIGGER details_changes
AFTER INSERT OR UPDATE OR DELETE ON details
FOR EACH ROW EXECUTE FUNCTION log_details_changes();

CREATE OR REPLACE FUNCTION log_counteragent_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('counteragent', 'INSERT', NEW.counteragent_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('counteragent', 'UPDATE', OLD.counteragent_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('counteragent', 'DELETE', OLD.counteragent_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы counteragent
CREATE TRIGGER counteragent_changes
AFTER INSERT OR UPDATE OR DELETE ON counteragent
FOR EACH ROW EXECUTE FUNCTION log_counteragent_changes();

CREATE OR REPLACE FUNCTION log_invoice_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('invoice', 'INSERT', NEW.invoice_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('invoice', 'UPDATE', OLD.invoice_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('invoice', 'DELETE', OLD.invoice_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы invoice
CREATE TRIGGER invoice_changes
AFTER INSERT OR UPDATE OR DELETE ON invoice
FOR EACH ROW EXECUTE FUNCTION log_invoice_changes();

CREATE OR REPLACE FUNCTION log_invoice_detail_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('invoice_detail', 'INSERT', NEW.invoiceID, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('invoice_detail', 'UPDATE', OLD.invoiceID, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('invoice_detail', 'DELETE', OLD.invoiceID, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы invoice_detail
CREATE TRIGGER invoice_detail_changes
AFTER INSERT OR UPDATE OR DELETE ON invoice_detail
FOR EACH ROW EXECUTE FUNCTION log_invoice_detail_changes();

CREATE OR REPLACE FUNCTION log_employee_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('employee', 'INSERT', NEW.employee_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('employee', 'UPDATE', OLD.employee_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('employee', 'DELETE', OLD.employee_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы employee
CREATE TRIGGER employee_changes
AFTER INSERT OR UPDATE OR DELETE ON employee
FOR EACH ROW EXECUTE FUNCTION log_employee_changes();

CREATE OR REPLACE FUNCTION log_employee_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('employee', 'INSERT', NEW.employee_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('employee', 'UPDATE', OLD.employee_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('employee', 'DELETE', OLD.employee_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы employee
CREATE TRIGGER employee_changes
AFTER INSERT OR UPDATE OR DELETE ON employee
FOR EACH ROW EXECUTE FUNCTION log_employee_changes();

CREATE OR REPLACE FUNCTION log_invoice_employee_changes() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO log_table (table_name, action_type, record_id, new_values)
        VALUES ('invoice_employee', 'INSERT', NEW.invoiceID, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values, new_values)
        VALUES ('invoice_employee', 'UPDATE', OLD.invoiceID, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO log_table (table_name, action_type, record_id, old_values)
        VALUES ('invoice_employee', 'DELETE', OLD.invoiceID, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для таблицы invoice_employee
CREATE TRIGGER invoice_employee_changes
AFTER INSERT OR UPDATE OR DELETE ON invoice_employee
FOR EACH ROW EXECUTE FUNCTION log_invoice_employee_changes();

CREATE OR REPLACE FUNCTION delete_invoice_details_view()
RETURNS TRIGGER AS $$
BEGIN
    -- Удаляем данные из таблицы invoice_employee (связь с invoice)
    DELETE FROM invoice_employee WHERE invoiceID = OLD.invoice_id;

    -- Удаляем данные из таблицы invoice_detail (связь с invoice)
    DELETE FROM invoice_detail WHERE invoiceID = OLD.invoice_id;

    -- Удаляем данные из таблицы invoice (основная информация по счету)
    DELETE FROM invoice WHERE invoice_id = OLD.invoice_id;

    -- Удаляем данные из таблицы details (если это нужно по логике)
    DELETE FROM details WHERE detail_id = OLD.detail_id;

    -- Удаляем данные из таблицы counteragent, если это необходимо
    -- Однако обратите внимание, что это может быть нежелательным в случае, если счет не является последним для этого контрагента
    -- DELETE FROM counteragent WHERE counteragent_id = OLD.counteragent_id;

    -- Возвращаем OLD, чтобы выполнить удаление
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_invoice_details_view()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем данные в таблице invoice
    UPDATE invoice
    SET
        counteragent_name = NEW.counteragent_name,   -- Из представления
        date_time = NEW.date_time,
        type_invoice = NEW.type_invoice,
        status = NEW.status
    WHERE invoice_id = OLD.invoice_id;

    -- Обновляем данные в таблице invoice_detail
    UPDATE invoice_detail
    SET
        quantity = NEW.quantity   -- Из представления
    WHERE invoiceID = OLD.invoice_id AND detailID = OLD.detail_id;

    -- Обновляем данные в таблице details
    UPDATE details
    SET
        weight = NEW.weight,
        type_detail = NEW.type_detail
    WHERE detail_id = OLD.detail_id;

    -- Возвращаем NEW, чтобы применить изменения
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер INSTEAD OF UPDATE для представления invoice_details_view
CREATE or replace TRIGGER invoice_details_view_update
INSTEAD OF UPDATE ON invoice_details_view
FOR EACH ROW EXECUTE FUNCTION update_invoice_details_view();


CREATE OR REPLACE FUNCTION insert_invoice_details_view() 
RETURNS TRIGGER AS $$
BEGIN
    -- Вставка данных в таблицу invoice
    INSERT INTO invoice (counteragentID, date_time, type_invoice, status)
    VALUES (NEW.counteragentID, NEW.date_time, NEW.type_invoice, NEW.status)
    RETURNING invoice_id INTO NEW.invoice_id;

    -- Вставка данных в таблицу invoice_detail
    INSERT INTO invoice_detail (invoiceID, detailID, quantity)
    VALUES (NEW.invoice_id, NEW.detailID, NEW.quantity);

    -- Вставка данных в таблицу invoice_employee
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (NEW.invoice_id, NEW.responsible, NEW.granted_access, NEW.when_granted);

    -- Возвращаем NEW, чтобы вставить данные в представление
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер INSTEAD OF INSERT для представления invoice_details_view
CREATE TRIGGER trg_insert_invoice_details_view
INSTEAD OF INSERT ON invoice_details_view
FOR EACH ROW EXECUTE FUNCTION insert_invoice_details_view();

CREATE OR REPLACE FUNCTION update_invoice_details_view()
RETURNS TRIGGER AS $$
DECLARE
    v_counteragent_id INT;
    v_detail_id INT;
    v_responsible INT;
    v_granted_access INT;
    v_when_granted TIMESTAMP;
BEGIN
    -- Получаем counteragent_id через вызов функции
    v_counteragent_id := get_counteragent_id(NEW.counteragent_name);

    -- Если контрагент не найден, выбрасываем ошибку
    IF v_counteragent_id IS NULL THEN
        RAISE EXCEPTION 'Counteragent with name "%" not found', NEW.counteragent_name;
    END IF;

    -- Обновляем данные в таблице invoice
    UPDATE invoice
    SET
        counteragentID = v_counteragent_id,  -- Используем найденный counteragent_id
        date_time = NEW.date_time,
        type_invoice = NEW.type_invoice,
        status = NEW.status
    WHERE invoice_id = OLD.invoice_id;

    -- Находим detail_id по названию детали (type_detail) из таблицы details
    SELECT detail_id
    INTO v_detail_id
    FROM details
    WHERE type_detail = NEW.type_detail
    LIMIT 1;

    -- Если деталь не найдена, выбрасываем ошибку
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Detail with type "%" not found', NEW.type_detail;
    END IF;

    -- Обновляем данные в таблице invoice_detail
    UPDATE invoice_detail
    SET
        quantity = NEW.quantity
    WHERE invoiceID = OLD.invoice_id AND detailID = v_detail_id;  -- Используем найденный v_detail_id

    -- Извлекаем данные для обновления таблицы invoice_employee
    SELECT responsible, granted_access, when_granted
    INTO v_responsible, v_granted_access, v_when_granted
    FROM invoice_employee
    WHERE invoiceID = OLD.invoice_id
    LIMIT 1;

    -- Если запись для invoice_employee не найдена, выбрасываем ошибку
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No employee record found for invoice with ID "%"', OLD.invoice_id;
    END IF;

    -- Обновляем данные в таблице invoice_employee
    UPDATE invoice_employee
    SET
        responsible = v_responsible,
        granted_access = v_granted_access,
        when_granted = v_when_granted
    WHERE invoiceID = OLD.invoice_id;

    -- Возвращаем NEW, чтобы применить изменения
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер INSTEAD OF UPDATE для представления invoice_details_view
CREATE or replace TRIGGER invoice_details_view_update
INSTEAD OF UPDATE ON invoice_details_view
FOR EACH ROW EXECUTE FUNCTION update_invoice_details_view();





CREATE OR REPLACE FUNCTION delete_invoice_details_view()
RETURNS TRIGGER AS $$
BEGIN
    -- Удаляем данные из таблицы invoice_employee
    DELETE FROM invoice_employee WHERE invoiceID = OLD.invoice_id;

    -- Удаляем данные из таблицы invoice_detail
    DELETE FROM invoice_detail WHERE invoiceID = OLD.invoice_id AND detailID = OLD.detail_id;

    -- Удаляем данные из таблицы invoice
    DELETE FROM invoice WHERE invoice_id = OLD.invoice_id;

    -- Удаляем данные из таблицы details
    DELETE FROM details WHERE detail_id = OLD.detail_id;

    -- Возвращаем OLD, чтобы выполнить удаление
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер INSTEAD OF DELETE для представления invoice_details_view
CREATE TRIGGER invoice_details_view_delete
INSTEAD OF DELETE ON invoice_details_view
FOR EACH ROW EXECUTE FUNCTION delete_invoice_details_view();


CREATE OR REPLACE FUNCTION get_counteragent_id(counteragent_name text)
RETURNS INT AS $$
BEGIN
    RETURN (SELECT counteragent_id
            FROM counteragent
            WHERE counteragent_name = $1  -- Используем $1 для параметра функции
            LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;




