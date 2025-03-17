

CREATE OR REPLACE FUNCTION log_invoice_changes() 
RETURNS TRIGGER AS $$
BEGIN
    -- Записываем в лог старое и новое значение статуса и даты-времени
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
    -- Назначаем сотрудника, ответственного за накладную, по умолчанию (например, сотрудник с employee_id = 1)
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (NEW.invoice_id, 1, 2, now());  -- "granted_access" назначен сотруднику с employee_id = 2, время - текущее
    
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
    -- Получаем значение поля type_invoice из таблицы invoice
    DECLARE
        invoice_type boolean;
        type_detail text;
    BEGIN
        -- Запрос к таблице invoice для получения значения поля type_invoice
        SELECT type_invoice INTO invoice_type
        FROM invoice
        WHERE invoice_id = NEW.invoice_id;

        -- Добавляем детали накладной
        INSERT INTO invoice_detail (invoiceID, detailID, quantity)
        VALUES (NEW.invoice_id, 
                (SELECT detail_id FROM details WHERE type_detail = 'Тормозные колодки' LIMIT 1), 
                10); 

        -- Логика для поставки (если type_invoice = true)
        IF invoice_type = true THEN
            -- Обновляем складские запасы, увеличиваем количество деталей
            UPDATE details
            SET stock_quantity = stock_quantity + 10  -- Здесь количество может быть динамическим
            WHERE detail_id = (SELECT detail_id FROM details WHERE type_detail = 'Тормозные колодки' LIMIT 1);

            -- Дополнительная логика для поставки (если требуется)
            -- Например, можно логировать событие или выполнять другие операции, связанные с поставкой
            RAISE NOTICE 'Поставка: добавлено 10 деталей типа Тормозные колодки';

        ELSE
            -- Логика для отгрузки (если type_invoice = false)
            -- Вы можете добавить сюда логику для отгрузки, например, уменьшать количество на складе
            UPDATE details
            SET stock_quantity = stock_quantity - 10  -- Уменьшаем количество при отгрузке
            WHERE detail_id = (SELECT detail_id FROM details WHERE type_detail = 'Тормозные колодки' LIMIT 1);

            RAISE NOTICE 'Отгрузка: удалено 10 деталей типа Тормозные колодки';
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
    -- При добавлении нового склада автоматически добавляется первая комната
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
    -- При добавлении новой комнаты автоматически создается первый стеллаж
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
    -- При добавлении нового стеллажа автоматически создается первая полка
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
    -- Удаление связанных комнат, стеллажей, полок и деталей при удалении склада
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
    -- При добавлении новой полки автоматически добавляется одна деталь
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
    -- Обновление связанных записей в details
    UPDATE details SET shelfID = NEW.shelf_id WHERE shelfID = OLD.shelf_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_shelfID_in_details
AFTER UPDATE ON shelf
FOR EACH ROW
EXECUTE FUNCTION update_shelfID_in_details();


