--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: add_default_detail(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_default_detail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении новой полки автоматически добавляется одна деталь
    INSERT INTO details (shelfID, weight, type_detail) VALUES (NEW.shelf_id, 5.0, 'Новая деталь');
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.add_default_detail() OWNER TO postgres;

--
-- Name: add_default_rack(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_default_rack() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении новой комнаты автоматически создается первый стеллаж
    INSERT INTO rack (roomID, rack_number) VALUES (NEW.room_id, 1);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.add_default_rack() OWNER TO postgres;

--
-- Name: add_default_room(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_default_room() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении нового склада автоматически добавляется первая комната
    INSERT INTO room (warehouseID, room_number) VALUES (NEW.warehouse_id, 1);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.add_default_room() OWNER TO postgres;

--
-- Name: add_default_shelf(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_default_shelf() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении нового стеллажа автоматически создается первая полка
    INSERT INTO shelf (rackID, shelf_number) VALUES (NEW.rack_id, 1);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.add_default_shelf() OWNER TO postgres;

--
-- Name: delete_invoice_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_invoice_details_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.delete_invoice_details_view() OWNER TO postgres;

--
-- Name: delete_related_data(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_related_data() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Удаление связанных комнат, стеллажей, полок и деталей при удалении склада
    DELETE FROM room WHERE warehouseID = OLD.warehouse_id;
    DELETE FROM rack WHERE roomID IN (SELECT room_id FROM room WHERE warehouseID = OLD.warehouse_id);
    DELETE FROM shelf WHERE rackID IN (SELECT rack_id FROM rack WHERE roomID IN (SELECT room_id FROM room WHERE warehouseID = OLD.warehouse_id));
    DELETE FROM details WHERE shelfID IN (SELECT shelf_id FROM shelf WHERE rackID IN (SELECT rack_id FROM rack WHERE roomID IN (SELECT room_id FROM room WHERE warehouseID = OLD.warehouse_id)));
    
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_related_data() OWNER TO postgres;

--
-- Name: delete_warehouse_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_warehouse_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.delete_warehouse_details() OWNER TO postgres;

--
-- Name: fill_invoice_detail(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fill_invoice_detail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
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
$$;


ALTER FUNCTION public.fill_invoice_detail() OWNER TO postgres;

--
-- Name: fill_invoice_employee(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fill_invoice_employee() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Назначаем сотрудника, ответственного за накладную, по умолчанию (например, сотрудник с employee_id = 1)
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (NEW.invoice_id, 1, 2, now());  -- "granted_access" назначен сотруднику с employee_id = 2, время - текущее
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fill_invoice_employee() OWNER TO postgres;

--
-- Name: get_counteragent_id(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_counteragent_id(counteragent_name text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
    RETURN (SELECT counteragent_id
            FROM counteragent
            WHERE counteragent_name = $1  -- Используем $1 для параметра функции
            LIMIT 1);
END;
$_$;


ALTER FUNCTION public.get_counteragent_id(counteragent_name text) OWNER TO postgres;

--
-- Name: insert_into_warehouse_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_into_warehouse_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    warehouse_id integer;
    room_id integer;
    rack_id integer;
    shelf_id integer;
BEGIN
    -- Добавляем запись в таблицу warehouse, если склад с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM warehouse WHERE warehouse_number = NEW.warehouse_number) THEN
        INSERT INTO warehouse (warehouse_number, address) 
        VALUES (NEW.warehouse_number, 'default address') 
        RETURNING warehouse.warehouse_id INTO warehouse_id;
    ELSE
        SELECT warehouse.warehouse_id INTO warehouse_id FROM warehouse WHERE warehouse_number = NEW.warehouse_number;
    END IF;

    -- Добавляем запись в таблицу room, если комната с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM room WHERE room_number = NEW.room_number AND warehouseID = warehouse_id) THEN
        INSERT INTO room (room_number, warehouseID) 
        VALUES (NEW.room_number, warehouse_id) 
        RETURNING room.room_id INTO room_id;
    ELSE
        SELECT room.room_id INTO room_id FROM room WHERE room_number = NEW.room_number AND warehouseID = warehouse_id;
    END IF;

    -- Добавляем запись в таблицу rack, если стеллаж с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM rack WHERE rack_number = NEW.rack_number AND roomID = room_id) THEN
        INSERT INTO rack (rack_number, roomID) 
        VALUES (NEW.rack_number, room_id) 
        RETURNING rack.rack_id INTO rack_id;
    ELSE
        SELECT rack.rack_id INTO rack_id FROM rack WHERE rack_number = NEW.rack_number AND roomID = room_id;
    END IF;

    -- Добавляем запись в таблицу shelf, если полка с таким номером не существует
    IF NOT EXISTS (SELECT 1 FROM shelf WHERE shelf_number = NEW.shelf_number AND rackID = rack_id) THEN
        INSERT INTO shelf (shelf_number, rackID) 
        VALUES (NEW.shelf_number, rack_id) 
        RETURNING shelf.shelf_id INTO shelf_id;
    ELSE
        SELECT shelf.shelf_id INTO shelf_id FROM shelf WHERE shelf_number = NEW.shelf_number AND rackID = rack_id;
    END IF;

    -- Добавляем деталь в таблицу details, связываем с полкой
    INSERT INTO details (shelfID, weight, type_detail) 
    VALUES (shelf_id, NEW.weight, NEW.type_detail);

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_into_warehouse_details() OWNER TO postgres;

--
-- Name: insert_invoice_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_invoice_details_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.insert_invoice_details_view() OWNER TO postgres;

--
-- Name: log_counteragent_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_counteragent_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_counteragent_changes() OWNER TO postgres;

--
-- Name: log_details_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_details_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_details_changes() OWNER TO postgres;

--
-- Name: log_employee_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_employee_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_employee_changes() OWNER TO postgres;

--
-- Name: log_invoice_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_invoice_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_invoice_changes() OWNER TO postgres;

--
-- Name: log_invoice_detail_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_invoice_detail_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_invoice_detail_changes() OWNER TO postgres;

--
-- Name: log_invoice_employee_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_invoice_employee_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_invoice_employee_changes() OWNER TO postgres;

--
-- Name: log_rack_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_rack_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_rack_changes() OWNER TO postgres;

--
-- Name: log_room_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_room_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_room_changes() OWNER TO postgres;

--
-- Name: log_shelf_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_shelf_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_shelf_changes() OWNER TO postgres;

--
-- Name: log_warehouse_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_warehouse_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_warehouse_changes() OWNER TO postgres;

--
-- Name: update_invoice_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_invoice_details_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_invoice_details_view() OWNER TO postgres;

--
-- Name: update_invoice_status_only(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_invoice_status_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_invoice_status_only() OWNER TO postgres;

--
-- Name: update_shelfid_in_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_shelfid_in_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Обновление связанных записей в details
    UPDATE details SET shelfID = NEW.shelf_id WHERE shelfID = OLD.shelf_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_shelfid_in_details() OWNER TO postgres;

--
-- Name: update_warehouse_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_warehouse_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_warehouse_details() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: counteragent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.counteragent (
    counteragent_id integer NOT NULL,
    counteragent_name character varying(128) NOT NULL,
    contact_person character varying(128) NOT NULL,
    phone_number bigint NOT NULL,
    address text NOT NULL
);


ALTER TABLE public.counteragent OWNER TO postgres;

--
-- Name: counteragent_counteragent_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.counteragent_counteragent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.counteragent_counteragent_id_seq OWNER TO postgres;

--
-- Name: counteragent_counteragent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.counteragent_counteragent_id_seq OWNED BY public.counteragent.counteragent_id;


--
-- Name: details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.details (
    detail_id integer NOT NULL,
    shelfid integer NOT NULL,
    weight double precision NOT NULL,
    type_detail text NOT NULL
);


ALTER TABLE public.details OWNER TO postgres;

--
-- Name: details_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.details_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.details_detail_id_seq OWNER TO postgres;

--
-- Name: details_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.details_detail_id_seq OWNED BY public.details.detail_id;


--
-- Name: details_shelfid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.details_shelfid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.details_shelfid_seq OWNER TO postgres;

--
-- Name: details_shelfid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.details_shelfid_seq OWNED BY public.details.shelfid;


--
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee (
    employee_id integer NOT NULL,
    employee_role character varying(25) NOT NULL,
    last_name character varying(35) NOT NULL,
    first_name character varying(35) NOT NULL,
    patronymic character varying(35) NOT NULL
);


ALTER TABLE public.employee OWNER TO postgres;

--
-- Name: employee_employee_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employee_employee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employee_employee_id_seq OWNER TO postgres;

--
-- Name: employee_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.employee_employee_id_seq OWNED BY public.employee.employee_id;


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice (
    invoice_id integer NOT NULL,
    counteragentid integer NOT NULL,
    date_time timestamp without time zone NOT NULL,
    type_invoice boolean NOT NULL,
    status boolean NOT NULL
);


ALTER TABLE public.invoice OWNER TO postgres;

--
-- Name: invoice_counteragentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_counteragentid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_counteragentid_seq OWNER TO postgres;

--
-- Name: invoice_counteragentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_counteragentid_seq OWNED BY public.invoice.counteragentid;


--
-- Name: invoice_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_detail (
    invoiceid integer NOT NULL,
    detailid integer NOT NULL,
    quantity integer NOT NULL
);


ALTER TABLE public.invoice_detail OWNER TO postgres;

--
-- Name: invoice_detail_detailid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_detail_detailid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_detail_detailid_seq OWNER TO postgres;

--
-- Name: invoice_detail_detailid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_detail_detailid_seq OWNED BY public.invoice_detail.detailid;


--
-- Name: invoice_detail_invoiceid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_detail_invoiceid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_detail_invoiceid_seq OWNER TO postgres;

--
-- Name: invoice_detail_invoiceid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_detail_invoiceid_seq OWNED BY public.invoice_detail.invoiceid;


--
-- Name: invoice_employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_employee (
    invoiceid integer NOT NULL,
    responsible integer NOT NULL,
    granted_access integer NOT NULL,
    when_granted timestamp without time zone NOT NULL
);


ALTER TABLE public.invoice_employee OWNER TO postgres;

--
-- Name: invoice_details_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.invoice_details_view AS
 SELECT inv.invoice_id,
    ca.counteragent_name,
    inv.date_time,
    inv.type_invoice,
    inv.status,
    det.type_detail,
    invd.quantity,
    emp.last_name AS responsible_last_name,
    emp.first_name AS responsible_first_name,
    emp.patronymic AS responsible_patronymic
   FROM (((((public.invoice inv
     JOIN public.invoice_detail invd ON ((inv.invoice_id = invd.invoiceid)))
     JOIN public.details det ON ((invd.detailid = det.detail_id)))
     JOIN public.invoice_employee inv_emp ON ((inv.invoice_id = inv_emp.invoiceid)))
     JOIN public.employee emp ON ((inv_emp.responsible = emp.employee_id)))
     JOIN public.counteragent ca ON ((inv.counteragentid = ca.counteragent_id)));


ALTER VIEW public.invoice_details_view OWNER TO postgres;

--
-- Name: invoice_employee_granted_access_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_employee_granted_access_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_employee_granted_access_seq OWNER TO postgres;

--
-- Name: invoice_employee_granted_access_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_employee_granted_access_seq OWNED BY public.invoice_employee.granted_access;


--
-- Name: invoice_employee_invoiceid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_employee_invoiceid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_employee_invoiceid_seq OWNER TO postgres;

--
-- Name: invoice_employee_invoiceid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_employee_invoiceid_seq OWNED BY public.invoice_employee.invoiceid;


--
-- Name: invoice_employee_responsible_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_employee_responsible_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_employee_responsible_seq OWNER TO postgres;

--
-- Name: invoice_employee_responsible_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_employee_responsible_seq OWNED BY public.invoice_employee.responsible;


--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_invoice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_invoice_id_seq OWNER TO postgres;

--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_invoice_id_seq OWNED BY public.invoice.invoice_id;


--
-- Name: log_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.log_table (
    log_id integer NOT NULL,
    table_name text NOT NULL,
    action_type text NOT NULL,
    record_id integer NOT NULL,
    action_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    old_values jsonb,
    new_values jsonb
);


ALTER TABLE public.log_table OWNER TO postgres;

--
-- Name: log_table_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.log_table_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.log_table_log_id_seq OWNER TO postgres;

--
-- Name: log_table_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.log_table_log_id_seq OWNED BY public.log_table.log_id;


--
-- Name: rack; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rack (
    rack_id integer NOT NULL,
    roomid integer NOT NULL,
    rack_number integer NOT NULL
);


ALTER TABLE public.rack OWNER TO postgres;

--
-- Name: rack_rack_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rack_rack_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rack_rack_id_seq OWNER TO postgres;

--
-- Name: rack_rack_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rack_rack_id_seq OWNED BY public.rack.rack_id;


--
-- Name: rack_roomid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rack_roomid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rack_roomid_seq OWNER TO postgres;

--
-- Name: rack_roomid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rack_roomid_seq OWNED BY public.rack.roomid;


--
-- Name: room; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room (
    room_id integer NOT NULL,
    warehouseid integer NOT NULL,
    room_number integer NOT NULL
);


ALTER TABLE public.room OWNER TO postgres;

--
-- Name: room_room_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.room_room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.room_room_id_seq OWNER TO postgres;

--
-- Name: room_room_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.room_room_id_seq OWNED BY public.room.room_id;


--
-- Name: room_warehouseid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.room_warehouseid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.room_warehouseid_seq OWNER TO postgres;

--
-- Name: room_warehouseid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.room_warehouseid_seq OWNED BY public.room.warehouseid;


--
-- Name: shelf; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shelf (
    shelf_id integer NOT NULL,
    rackid integer NOT NULL,
    shelf_number integer NOT NULL
);


ALTER TABLE public.shelf OWNER TO postgres;

--
-- Name: shelf_rackid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shelf_rackid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shelf_rackid_seq OWNER TO postgres;

--
-- Name: shelf_rackid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shelf_rackid_seq OWNED BY public.shelf.rackid;


--
-- Name: shelf_shelf_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shelf_shelf_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shelf_shelf_id_seq OWNER TO postgres;

--
-- Name: shelf_shelf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shelf_shelf_id_seq OWNED BY public.shelf.shelf_id;


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse (
    warehouse_id integer NOT NULL,
    warehouse_number integer NOT NULL,
    address text NOT NULL
);


ALTER TABLE public.warehouse OWNER TO postgres;

--
-- Name: warehouse_details_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.warehouse_details_view AS
 SELECT w.warehouse_number,
    r.room_number,
    rk.rack_number,
    s.shelf_number,
    d.type_detail,
    d.weight,
    d.detail_id
   FROM ((((public.warehouse w
     JOIN public.room r ON ((w.warehouse_id = r.warehouseid)))
     JOIN public.rack rk ON ((r.room_id = rk.roomid)))
     JOIN public.shelf s ON ((rk.rack_id = s.rackid)))
     JOIN public.details d ON ((s.shelf_id = d.shelfid)));


ALTER VIEW public.warehouse_details_view OWNER TO postgres;

--
-- Name: warehouse_warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.warehouse_warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.warehouse_warehouse_id_seq OWNER TO postgres;

--
-- Name: warehouse_warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.warehouse_warehouse_id_seq OWNED BY public.warehouse.warehouse_id;


--
-- Name: counteragent counteragent_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.counteragent ALTER COLUMN counteragent_id SET DEFAULT nextval('public.counteragent_counteragent_id_seq'::regclass);


--
-- Name: details detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details ALTER COLUMN detail_id SET DEFAULT nextval('public.details_detail_id_seq'::regclass);


--
-- Name: details shelfid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details ALTER COLUMN shelfid SET DEFAULT nextval('public.details_shelfid_seq'::regclass);


--
-- Name: employee employee_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee ALTER COLUMN employee_id SET DEFAULT nextval('public.employee_employee_id_seq'::regclass);


--
-- Name: invoice invoice_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice ALTER COLUMN invoice_id SET DEFAULT nextval('public.invoice_invoice_id_seq'::regclass);


--
-- Name: invoice counteragentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice ALTER COLUMN counteragentid SET DEFAULT nextval('public.invoice_counteragentid_seq'::regclass);


--
-- Name: invoice_detail invoiceid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_detail ALTER COLUMN invoiceid SET DEFAULT nextval('public.invoice_detail_invoiceid_seq'::regclass);


--
-- Name: invoice_detail detailid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_detail ALTER COLUMN detailid SET DEFAULT nextval('public.invoice_detail_detailid_seq'::regclass);


--
-- Name: invoice_employee invoiceid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee ALTER COLUMN invoiceid SET DEFAULT nextval('public.invoice_employee_invoiceid_seq'::regclass);


--
-- Name: invoice_employee responsible; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee ALTER COLUMN responsible SET DEFAULT nextval('public.invoice_employee_responsible_seq'::regclass);


--
-- Name: invoice_employee granted_access; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee ALTER COLUMN granted_access SET DEFAULT nextval('public.invoice_employee_granted_access_seq'::regclass);


--
-- Name: log_table log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_table ALTER COLUMN log_id SET DEFAULT nextval('public.log_table_log_id_seq'::regclass);


--
-- Name: rack rack_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack ALTER COLUMN rack_id SET DEFAULT nextval('public.rack_rack_id_seq'::regclass);


--
-- Name: rack roomid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack ALTER COLUMN roomid SET DEFAULT nextval('public.rack_roomid_seq'::regclass);


--
-- Name: room room_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room ALTER COLUMN room_id SET DEFAULT nextval('public.room_room_id_seq'::regclass);


--
-- Name: room warehouseid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room ALTER COLUMN warehouseid SET DEFAULT nextval('public.room_warehouseid_seq'::regclass);


--
-- Name: shelf shelf_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shelf ALTER COLUMN shelf_id SET DEFAULT nextval('public.shelf_shelf_id_seq'::regclass);


--
-- Name: shelf rackid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shelf ALTER COLUMN rackid SET DEFAULT nextval('public.shelf_rackid_seq'::regclass);


--
-- Name: warehouse warehouse_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse ALTER COLUMN warehouse_id SET DEFAULT nextval('public.warehouse_warehouse_id_seq'::regclass);


--
-- Data for Name: counteragent; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.counteragent (counteragent_id, counteragent_name, contact_person, phone_number, address) FROM stdin;
1	ООО "АвтоЗапчасти"	Иван Иванов	1234567890	ул. Бизнеса, 1, Город A
2	ЗАО "ТехЗапчасть"	Анна Смирнова	2345678901	ул. Рыночная, 2, Город B
3	ООО "МоторТехника"	Алексей Сидоров	3456789012	проспект Инноваций, 3, Город C
4	ИП "АвтоМир"	Мария Кузнецова	4567890123	ул. Стиля, 4, Город D
5	ООО "Детали и Механизмы"	Ольга Павлова	5678901234	ул. Уютная, 5, Город E
\.


--
-- Data for Name: details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.details (detail_id, shelfid, weight, type_detail) FROM stdin;
2	2	5	Тормозные колодки
3	3	20.7	Подвеска
4	4	7.3	Фары
5	5	15.2	Шины
1	1	5	Двигатель
\.


--
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employee (employee_id, employee_role, last_name, first_name, patronymic) FROM stdin;
1	Кладовщик	Иванов	Иван	Иванович
2	Менеджер склада	Петров	Петр	Петрович
3	Владелец	Сидоров	Сидр	Сидорович
4	Кладовщик	Федоров	Федор	Федорович
5	Менеджер склада	Смирнов	Сергей	Сергеевич
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice (invoice_id, counteragentid, date_time, type_invoice, status) FROM stdin;
2	2	2025-03-02 10:30:00	f	t
3	3	2025-03-03 14:45:00	t	t
4	4	2025-03-04 11:20:00	f	f
5	5	2025-03-05 15:00:00	t	t
1	1	2025-03-01 09:00:00	t	f
\.


--
-- Data for Name: invoice_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_detail (invoiceid, detailid, quantity) FROM stdin;
1	1	10
2	2	5
3	3	20
4	4	7
5	5	15
1	5	10
\.


--
-- Data for Name: invoice_employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_employee (invoiceid, responsible, granted_access, when_granted) FROM stdin;
2	3	4	2025-03-02 10:35:00
3	2	5	2025-03-03 14:50:00
4	4	1	2025-03-04 11:25:00
5	5	3	2025-03-05 15:05:00
1	1	2	2025-03-01 09:05:00
\.


--
-- Data for Name: log_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.log_table (log_id, table_name, action_type, record_id, action_time, old_values, new_values) FROM stdin;
7	invoice	UPDATE	1	2025-03-24 04:01:13.192941	{"status": false, "date_time": "2025-03-01T09:00:00", "invoice_id": 1, "type_invoice": false, "counteragentid": 1}	{"status": false, "date_time": "2025-03-01T09:00:00", "invoice_id": 1, "type_invoice": true, "counteragentid": 1}
8	invoice_detail	UPDATE	1	2025-03-24 04:01:13.192941	{"detailid": 5, "quantity": 10, "invoiceid": 1}	{"detailid": 5, "quantity": 10, "invoiceid": 1}
9	invoice_employee	UPDATE	1	2025-03-24 04:01:13.192941	{"invoiceid": 1, "responsible": 1, "when_granted": "2025-03-01T09:05:00", "granted_access": 2}	{"invoiceid": 1, "responsible": 1, "when_granted": "2025-03-01T09:05:00", "granted_access": 2}
10	details	UPDATE	1	2025-03-24 04:02:47.4348	{"weight": 12.5, "shelfid": 1, "detail_id": 1, "type_detail": "Двигатель"}	{"weight": 5, "shelfid": 1, "detail_id": 1, "type_detail": "Двигатель"}
11	details	UPDATE	1	2025-03-24 04:02:47.4348	{"weight": 5, "shelfid": 1, "detail_id": 1, "type_detail": "Двигатель"}	{"weight": 5, "shelfid": 1, "detail_id": 1, "type_detail": "Двигатель"}
\.


--
-- Data for Name: rack; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rack (rack_id, roomid, rack_number) FROM stdin;
1	1	10
2	2	20
3	3	30
4	4	40
5	5	50
\.


--
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.room (room_id, warehouseid, room_number) FROM stdin;
1	1	1
2	2	2
3	3	3
4	4	4
5	5	5
\.


--
-- Data for Name: shelf; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shelf (shelf_id, rackid, shelf_number) FROM stdin;
1	1	100
2	2	200
3	3	300
4	4	400
5	5	500
\.


--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.warehouse (warehouse_id, warehouse_number, address) FROM stdin;
1	101	ул. Дубовая, 1234, Город A
2	102	ул. Кленовая, 5678, Город B
3	103	ул. Сосновая, 9101, Город C
4	104	ул. Кедровая, 1213, Город D
5	105	ул. Вязовая, 1415, Город E
\.


--
-- Name: counteragent_counteragent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.counteragent_counteragent_id_seq', 5, true);


--
-- Name: details_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.details_detail_id_seq', 10, true);


--
-- Name: details_shelfid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.details_shelfid_seq', 1, false);


--
-- Name: employee_employee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.employee_employee_id_seq', 8, true);


--
-- Name: invoice_counteragentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_counteragentid_seq', 1, false);


--
-- Name: invoice_detail_detailid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_detail_detailid_seq', 1, false);


--
-- Name: invoice_detail_invoiceid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_detail_invoiceid_seq', 1, true);


--
-- Name: invoice_employee_granted_access_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_employee_granted_access_seq', 1, false);


--
-- Name: invoice_employee_invoiceid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_employee_invoiceid_seq', 1, false);


--
-- Name: invoice_employee_responsible_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_employee_responsible_seq', 1, false);


--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_invoice_id_seq', 10, true);


--
-- Name: log_table_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.log_table_log_id_seq', 11, true);


--
-- Name: rack_rack_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rack_rack_id_seq', 5, true);


--
-- Name: rack_roomid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rack_roomid_seq', 1, false);


--
-- Name: room_room_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.room_room_id_seq', 5, true);


--
-- Name: room_warehouseid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.room_warehouseid_seq', 1, false);


--
-- Name: shelf_rackid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shelf_rackid_seq', 1, false);


--
-- Name: shelf_shelf_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shelf_shelf_id_seq', 5, true);


--
-- Name: warehouse_warehouse_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.warehouse_warehouse_id_seq', 5, true);


--
-- Name: counteragent counteragent_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.counteragent
    ADD CONSTRAINT counteragent_pkey PRIMARY KEY (counteragent_id);


--
-- Name: details details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details
    ADD CONSTRAINT details_pkey PRIMARY KEY (detail_id);


--
-- Name: employee employee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (employee_id);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (invoice_id);


--
-- Name: log_table log_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_table
    ADD CONSTRAINT log_table_pkey PRIMARY KEY (log_id);


--
-- Name: rack rack_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_pkey PRIMARY KEY (rack_id);


--
-- Name: room room_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (room_id);


--
-- Name: shelf shelf_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shelf
    ADD CONSTRAINT shelf_pkey PRIMARY KEY (shelf_id);


--
-- Name: warehouse warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (warehouse_id);


--
-- Name: counteragent counteragent_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER counteragent_changes AFTER INSERT OR DELETE OR UPDATE ON public.counteragent FOR EACH ROW EXECUTE FUNCTION public.log_counteragent_changes();


--
-- Name: warehouse_details_view delete_warehouse_details_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER delete_warehouse_details_trigger INSTEAD OF DELETE ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.delete_warehouse_details();


--
-- Name: details details_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER details_changes AFTER INSERT OR DELETE OR UPDATE ON public.details FOR EACH ROW EXECUTE FUNCTION public.log_details_changes();


--
-- Name: employee employee_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER employee_changes AFTER INSERT OR DELETE OR UPDATE ON public.employee FOR EACH ROW EXECUTE FUNCTION public.log_employee_changes();


--
-- Name: invoice invoice_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER invoice_changes AFTER INSERT OR DELETE OR UPDATE ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.log_invoice_changes();


--
-- Name: invoice_detail invoice_detail_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER invoice_detail_changes AFTER INSERT OR DELETE OR UPDATE ON public.invoice_detail FOR EACH ROW EXECUTE FUNCTION public.log_invoice_detail_changes();


--
-- Name: invoice_details_view invoice_details_view_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER invoice_details_view_delete INSTEAD OF DELETE ON public.invoice_details_view FOR EACH ROW EXECUTE FUNCTION public.delete_invoice_details_view();


--
-- Name: invoice_details_view invoice_details_view_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER invoice_details_view_update INSTEAD OF UPDATE ON public.invoice_details_view FOR EACH ROW EXECUTE FUNCTION public.update_invoice_details_view();


--
-- Name: invoice_employee invoice_employee_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER invoice_employee_changes AFTER INSERT OR DELETE OR UPDATE ON public.invoice_employee FOR EACH ROW EXECUTE FUNCTION public.log_invoice_employee_changes();


--
-- Name: rack rack_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER rack_changes AFTER INSERT OR DELETE OR UPDATE ON public.rack FOR EACH ROW EXECUTE FUNCTION public.log_rack_changes();


--
-- Name: room room_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER room_changes AFTER INSERT OR DELETE OR UPDATE ON public.room FOR EACH ROW EXECUTE FUNCTION public.log_room_changes();


--
-- Name: shelf shelf_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER shelf_changes AFTER INSERT OR DELETE OR UPDATE ON public.shelf FOR EACH ROW EXECUTE FUNCTION public.log_shelf_changes();


--
-- Name: shelf trg_add_default_detail; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_add_default_detail AFTER INSERT ON public.shelf FOR EACH ROW EXECUTE FUNCTION public.add_default_detail();


--
-- Name: room trg_add_default_rack; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_add_default_rack AFTER INSERT ON public.room FOR EACH ROW EXECUTE FUNCTION public.add_default_rack();


--
-- Name: warehouse trg_add_default_room; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_add_default_room AFTER INSERT ON public.warehouse FOR EACH ROW EXECUTE FUNCTION public.add_default_room();


--
-- Name: rack trg_add_default_shelf; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_add_default_shelf AFTER INSERT ON public.rack FOR EACH ROW EXECUTE FUNCTION public.add_default_shelf();


--
-- Name: invoice trg_delete_invoice_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_delete_invoice_details AFTER DELETE ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.delete_invoice_details_view();


--
-- Name: warehouse trg_delete_related_data; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_delete_related_data BEFORE DELETE ON public.warehouse FOR EACH ROW EXECUTE FUNCTION public.delete_related_data();


--
-- Name: invoice trg_fill_invoice_detail; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_fill_invoice_detail AFTER INSERT ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.fill_invoice_detail();


--
-- Name: invoice trg_fill_invoice_employee; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_fill_invoice_employee AFTER INSERT ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.fill_invoice_employee();


--
-- Name: invoice_detail trg_insert_invoice_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_insert_invoice_details AFTER INSERT ON public.invoice_detail FOR EACH ROW EXECUTE FUNCTION public.insert_invoice_details_view();


--
-- Name: invoice_details_view trg_insert_invoice_details_view; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_insert_invoice_details_view INSTEAD OF INSERT ON public.invoice_details_view FOR EACH ROW EXECUTE FUNCTION public.insert_invoice_details_view();


--
-- Name: shelf trg_update_shelfid_in_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_shelfid_in_details AFTER UPDATE ON public.shelf FOR EACH ROW EXECUTE FUNCTION public.update_shelfid_in_details();


--
-- Name: warehouse_details_view trigger_delete_warehouse_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_delete_warehouse_details INSTEAD OF DELETE ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.delete_warehouse_details();


--
-- Name: warehouse_details_view trigger_insert_warehouse_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_insert_warehouse_details INSTEAD OF INSERT ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.insert_into_warehouse_details();


--
-- Name: warehouse_details_view trigger_update_warehouse_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_warehouse_details INSTEAD OF UPDATE ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.update_warehouse_details();


--
-- Name: invoice_details_view update_invoice_status_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_invoice_status_trigger INSTEAD OF UPDATE ON public.invoice_details_view FOR EACH ROW EXECUTE FUNCTION public.update_invoice_status_only();


--
-- Name: warehouse_details_view update_warehouse_details_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_warehouse_details_trigger INSTEAD OF UPDATE ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.update_warehouse_details();


--
-- Name: warehouse warehouse_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER warehouse_changes AFTER INSERT OR DELETE OR UPDATE ON public.warehouse FOR EACH ROW EXECUTE FUNCTION public.log_warehouse_changes();


--
-- Name: details details_shelfid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details
    ADD CONSTRAINT details_shelfid_fkey FOREIGN KEY (shelfid) REFERENCES public.shelf(shelf_id);


--
-- Name: invoice invoice_counteragentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_counteragentid_fkey FOREIGN KEY (counteragentid) REFERENCES public.counteragent(counteragent_id);


--
-- Name: invoice_detail invoice_detail_detailid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_detail
    ADD CONSTRAINT invoice_detail_detailid_fkey FOREIGN KEY (detailid) REFERENCES public.details(detail_id);


--
-- Name: invoice_detail invoice_detail_invoiceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_detail
    ADD CONSTRAINT invoice_detail_invoiceid_fkey FOREIGN KEY (invoiceid) REFERENCES public.invoice(invoice_id);


--
-- Name: invoice_employee invoice_employee_granted_access_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_granted_access_fkey FOREIGN KEY (granted_access) REFERENCES public.employee(employee_id);


--
-- Name: invoice_employee invoice_employee_invoiceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_invoiceid_fkey FOREIGN KEY (invoiceid) REFERENCES public.invoice(invoice_id);


--
-- Name: invoice_employee invoice_employee_responsible_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_responsible_fkey FOREIGN KEY (responsible) REFERENCES public.employee(employee_id);


--
-- Name: rack rack_roomid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_roomid_fkey FOREIGN KEY (roomid) REFERENCES public.room(room_id);


--
-- Name: room room_warehouseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_warehouseid_fkey FOREIGN KEY (warehouseid) REFERENCES public.warehouse(warehouse_id);


--
-- Name: shelf shelf_rackid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shelf
    ADD CONSTRAINT shelf_rackid_fkey FOREIGN KEY (rackid) REFERENCES public.rack(rack_id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO warehouse_owner;


--
-- Name: FUNCTION add_default_detail(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.add_default_detail() TO warehouse_owner;


--
-- Name: FUNCTION add_default_rack(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.add_default_rack() TO warehouse_owner;


--
-- Name: FUNCTION add_default_room(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.add_default_room() TO warehouse_owner;


--
-- Name: FUNCTION add_default_shelf(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.add_default_shelf() TO warehouse_owner;


--
-- Name: FUNCTION delete_invoice_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_invoice_details_view() TO warehouse_owner;


--
-- Name: FUNCTION delete_related_data(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_related_data() TO warehouse_owner;


--
-- Name: FUNCTION delete_warehouse_details(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_warehouse_details() TO warehouse_owner;


--
-- Name: FUNCTION fill_invoice_detail(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fill_invoice_detail() TO warehouse_owner;


--
-- Name: FUNCTION fill_invoice_employee(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fill_invoice_employee() TO warehouse_owner;


--
-- Name: FUNCTION get_counteragent_id(counteragent_name text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_counteragent_id(counteragent_name text) TO warehouse_owner;


--
-- Name: FUNCTION insert_into_warehouse_details(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_into_warehouse_details() TO warehouse_owner;


--
-- Name: FUNCTION insert_invoice_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_invoice_details_view() TO warehouse_owner;


--
-- Name: FUNCTION log_counteragent_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_counteragent_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_details_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_details_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_employee_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_employee_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_invoice_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_invoice_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_invoice_detail_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_invoice_detail_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_invoice_employee_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_invoice_employee_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_rack_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_rack_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_room_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_room_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_shelf_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_shelf_changes() TO warehouse_owner;


--
-- Name: FUNCTION log_warehouse_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_warehouse_changes() TO warehouse_owner;


--
-- Name: FUNCTION update_invoice_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_invoice_details_view() TO warehouse_owner;


--
-- Name: FUNCTION update_invoice_status_only(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_invoice_status_only() TO warehouse_owner;


--
-- Name: FUNCTION update_shelfid_in_details(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_shelfid_in_details() TO warehouse_owner;


--
-- Name: FUNCTION update_warehouse_details(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_warehouse_details() TO warehouse_owner;


--
-- Name: TABLE counteragent; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.counteragent TO warehouse_manager;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.counteragent TO warehouse_owner;


--
-- Name: SEQUENCE counteragent_counteragent_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.counteragent_counteragent_id_seq TO warehouse_owner;


--
-- Name: TABLE details; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.details TO warehouse_clerk;
GRANT SELECT ON TABLE public.details TO warehouse_manager;
GRANT SELECT ON TABLE public.details TO warehouse_owner;


--
-- Name: SEQUENCE details_detail_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.details_detail_id_seq TO warehouse_clerk;
GRANT SELECT,USAGE ON SEQUENCE public.details_detail_id_seq TO warehouse_owner;


--
-- Name: SEQUENCE details_shelfid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.details_shelfid_seq TO warehouse_owner;


--
-- Name: TABLE employee; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.employee TO warehouse_owner;


--
-- Name: SEQUENCE employee_employee_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.employee_employee_id_seq TO warehouse_owner;
GRANT SELECT,USAGE ON SEQUENCE public.employee_employee_id_seq TO warehouse_manager;


--
-- Name: TABLE invoice; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.invoice TO warehouse_clerk;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice TO warehouse_owner;


--
-- Name: COLUMN invoice.status; Type: ACL; Schema: public; Owner: postgres
--

GRANT UPDATE(status) ON TABLE public.invoice TO warehouse_clerk;


--
-- Name: SEQUENCE invoice_counteragentid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_counteragentid_seq TO warehouse_owner;


--
-- Name: TABLE invoice_detail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice_detail TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice_detail TO warehouse_owner;
GRANT SELECT ON TABLE public.invoice_detail TO warehouse_clerk;


--
-- Name: SEQUENCE invoice_detail_detailid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_detail_detailid_seq TO warehouse_owner;


--
-- Name: SEQUENCE invoice_detail_invoiceid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_detail_invoiceid_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_detail_invoiceid_seq TO warehouse_owner;


--
-- Name: TABLE invoice_employee; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice_employee TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice_employee TO warehouse_owner;
GRANT SELECT ON TABLE public.invoice_employee TO warehouse_clerk;


--
-- Name: TABLE invoice_details_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.invoice_details_view TO warehouse_owner;
GRANT SELECT ON TABLE public.invoice_details_view TO warehouse_clerk;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice_details_view TO warehouse_manager;


--
-- Name: COLUMN invoice_details_view.status; Type: ACL; Schema: public; Owner: postgres
--

GRANT UPDATE(status) ON TABLE public.invoice_details_view TO warehouse_clerk;


--
-- Name: SEQUENCE invoice_employee_granted_access_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_employee_granted_access_seq TO warehouse_owner;


--
-- Name: SEQUENCE invoice_employee_invoiceid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_employee_invoiceid_seq TO warehouse_owner;


--
-- Name: SEQUENCE invoice_employee_responsible_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_employee_responsible_seq TO warehouse_owner;


--
-- Name: SEQUENCE invoice_invoice_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_invoice_id_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_invoice_id_seq TO warehouse_owner;


--
-- Name: TABLE log_table; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.log_table TO warehouse_owner;
GRANT SELECT,INSERT ON TABLE public.log_table TO warehouse_clerk;
GRANT SELECT,INSERT ON TABLE public.log_table TO warehouse_manager;


--
-- Name: SEQUENCE log_table_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.log_table_log_id_seq TO warehouse_clerk;
GRANT SELECT,USAGE ON SEQUENCE public.log_table_log_id_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.log_table_log_id_seq TO warehouse_owner;


--
-- Name: TABLE rack; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.rack TO warehouse_clerk;
GRANT SELECT ON TABLE public.rack TO warehouse_owner;


--
-- Name: SEQUENCE rack_rack_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.rack_rack_id_seq TO warehouse_owner;


--
-- Name: SEQUENCE rack_roomid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.rack_roomid_seq TO warehouse_owner;


--
-- Name: TABLE room; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.room TO warehouse_clerk;
GRANT SELECT ON TABLE public.room TO warehouse_owner;


--
-- Name: SEQUENCE room_room_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.room_room_id_seq TO warehouse_owner;


--
-- Name: SEQUENCE room_warehouseid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.room_warehouseid_seq TO warehouse_owner;


--
-- Name: TABLE shelf; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.shelf TO warehouse_clerk;
GRANT SELECT ON TABLE public.shelf TO warehouse_owner;


--
-- Name: SEQUENCE shelf_rackid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.shelf_rackid_seq TO warehouse_owner;


--
-- Name: SEQUENCE shelf_shelf_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.shelf_shelf_id_seq TO warehouse_owner;


--
-- Name: TABLE warehouse; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.warehouse TO warehouse_clerk;
GRANT SELECT ON TABLE public.warehouse TO warehouse_owner;


--
-- Name: TABLE warehouse_details_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.warehouse_details_view TO warehouse_owner;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.warehouse_details_view TO warehouse_clerk;
GRANT SELECT ON TABLE public.warehouse_details_view TO warehouse_manager;


--
-- Name: SEQUENCE warehouse_warehouse_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.warehouse_warehouse_id_seq TO warehouse_owner;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO warehouse_owner;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO warehouse_owner;


--
-- PostgreSQL database dump complete
--

