

CREATE OR REPLACE FUNCTION log_invoice_changes() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO invoice_log (invoice_id, old_status, new_status, old_date_time, new_date_time, changed_by)
    VALUES (OLD.invoice_id, OLD.status, NEW.status, OLD.date_time, NEW.date_time, current_user);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_invoice_changes
AFTER UPDATE ON invoice
FOR EACH ROW
EXECUTE FUNCTION log_invoice_changes();


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


-- Триггер для обновления записи в таблице invoice, invoice_detail и invoice_employee
CREATE OR REPLACE FUNCTION update_invoice_details_view() 
RETURNS TRIGGER AS $$
BEGIN
    -- Обновление данных в таблице invoice
    UPDATE invoice
    SET counteragentID = NEW.counteragentID,
        date_time = NEW.date_time,
        type_invoice = NEW.type_invoice,
        status = NEW.status
    WHERE invoice_id = NEW.invoice_id;

    -- Обновление данных в invoice_detail
    UPDATE invoice_detail
    SET detailID = NEW.detailID, 
        quantity = NEW.quantity
    WHERE invoiceID = NEW.invoice_id;

    -- Обновление данных в invoice_employee
    UPDATE invoice_employee
    SET responsible = NEW.responsible, 
        granted_access = NEW.granted_access, 
        when_granted = NEW.when_granted
    WHERE invoiceID = NEW.invoice_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Применение триггера для таблицы invoice
CREATE TRIGGER trg_update_invoice_details
AFTER UPDATE ON invoice
FOR EACH ROW
EXECUTE FUNCTION update_invoice_details_view();

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

