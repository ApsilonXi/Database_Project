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


CREATE OR REPLACE FUNCTION insert_invoice_details_view() 
RETURNS TRIGGER AS $$
BEGIN
    -- Получаем counteragentID, используя counteragent_name из представления
    SELECT counteragent_id INTO NEW.counteragentID
    FROM counteragent
    WHERE counteragent_name = NEW.counteragent_name
    LIMIT 1;
    
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

CREATE or replace TRIGGER insert_invoice_details_view_trigger
INSTEAD OF INSERT ON invoice_details_view
FOR EACH ROW
EXECUTE FUNCTION insert_invoice_details_view();


-- Создаем триггер INSTEAD OF INSERT для представления invoice_details_view
CREATE TRIGGER trg_insert_invoice_details_view
INSTEAD OF INSERT ON invoice_details_view
FOR EACH ROW EXECUTE FUNCTION insert_invoice_details_view();


CREATE OR REPLACE FUNCTION delete_invoice_details_view()
RETURNS TRIGGER AS $$
BEGIN
    -- Удаляем данные из таблицы invoice_detail
    DELETE FROM invoice_detail 
    WHERE invoiceID = OLD.invoice_id;

    -- Удаляем данные из таблицы invoice_employee
    DELETE FROM invoice_employee
    WHERE invoiceID = OLD.invoice_id;

    -- Удаляем данные из таблицы invoice
    DELETE FROM invoice
    WHERE invoice_id = OLD.invoice_id;

    -- Возвращаем OLD для выполнения удаления записи из представления
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер INSTEAD OF DELETE для представления invoice_details_view
CREATE or replace TRIGGER invoice_details_view_delete
INSTEAD OF DELETE ON invoice_details_view
FOR EACH ROW EXECUTE FUNCTION delete_invoice_details_view();



CREATE OR REPLACE FUNCTION update_warehouse_details_view()
RETURNS trigger AS $$
BEGIN
    -- Обновляем таблицу details
    UPDATE details
    SET type_detail = NEW.type_detail, weight = NEW.weight
    WHERE detail_id = OLD.detail_id;

    -- Обновляем таблицу shelf
    UPDATE shelf
    SET shelf_number = NEW.shelf_number
    WHERE shelf_id = (SELECT shelfID FROM details WHERE detail_id = OLD.detail_id);

    -- Обновляем таблицу rack
    UPDATE rack
    SET rack_number = NEW.rack_number
    WHERE rack_id = (SELECT rackID FROM shelf WHERE shelf_id = (SELECT shelfID FROM details WHERE detail_id = OLD.detail_id));

    -- Обновляем таблицу room
    UPDATE room
    SET room_number = NEW.room_number
    WHERE room_id = (SELECT roomID FROM rack WHERE rack_id = (SELECT rackID FROM shelf WHERE shelf_id = (SELECT shelfID FROM details WHERE detail_id = OLD.detail_id)));

    -- Обновляем таблицу warehouse
    UPDATE warehouse
    SET warehouse_number = NEW.warehouse_number
    WHERE warehouse_id = (SELECT warehouseID FROM room WHERE room_id = (SELECT roomID FROM rack WHERE rack_id = (SELECT rackID FROM shelf WHERE shelf_id = (SELECT shelfID FROM details WHERE detail_id = OLD.detail_id))));

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_update_warehouse_details_view
INSTEAD OF UPDATE ON warehouse_details_view
FOR EACH ROW
EXECUTE FUNCTION update_warehouse_details_view();


CREATE OR REPLACE FUNCTION convert_type_invoice() 
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.type_invoice = 'отгрузка' THEN
        NEW.type_invoice := FALSE;
    ELSIF NEW.type_invoice = 'выгрузка' THEN
        NEW.type_invoice := TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION convert_status() 
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'в процессе' THEN
        NEW.status := FALSE;
    ELSIF NEW.status = 'завершено' THEN
        NEW.status := TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_type_invoice
BEFORE INSERT OR UPDATE ON invoice
FOR EACH ROW
EXECUTE FUNCTION convert_type_invoice();

CREATE TRIGGER set_status
BEFORE INSERT OR UPDATE ON invoice
FOR EACH ROW
EXECUTE FUNCTION convert_status();



