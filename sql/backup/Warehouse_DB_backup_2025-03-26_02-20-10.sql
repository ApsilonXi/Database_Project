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
-- Name: convert_text_to_boolean(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.convert_text_to_boolean(text_value text, field_type text DEFAULT 'status'::text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    text_value := LOWER(TRIM(text_value));
    
    -- Для типа накладной
    IF field_type = 'type' THEN
        RETURN text_value IN ('выгрузка', 'выгрузить', 'отправка', 'true', '1', 'да', 'yes', 'y');
    -- Для статуса
    ELSE
        RETURN text_value IN ('завершено', 'готово', 'выполнено', 'done', 'true', '1', 'да', 'yes', 'y');
    END IF;
END;
$$;


ALTER FUNCTION public.convert_text_to_boolean(text_value text, field_type text) OWNER TO postgres;

--
-- Name: delete_invoice_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_invoice_details_view() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Удаляем связанные записи в правильном порядке (чтобы избежать нарушений ограничений внешнего ключа)
    
    -- 1. Удаляем связи с сотрудниками
    DELETE FROM invoice_employee WHERE invoiceID = OLD.invoice_id;
    
    -- 2. Удаляем детали накладной
    DELETE FROM invoice_detail WHERE invoiceID = OLD.invoice_id;
    
    -- 3. Удаляем саму накладную
    DELETE FROM invoice WHERE invoice_id = OLD.invoice_id;
    
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
-- Name: get_employee_id(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_employee_id(p_last_name character varying, p_first_name character varying, p_patronymic character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_id integer;
BEGIN
    SELECT employee_id INTO v_id 
    FROM employee 
    WHERE last_name = p_last_name 
    AND first_name = p_first_name 
    AND patronymic = p_patronymic;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Сотрудник % % % не найден', 
            p_last_name, p_first_name, p_patronymic;
    END IF;
    
    RETURN v_id;
END;
$$;


ALTER FUNCTION public.get_employee_id(p_last_name character varying, p_first_name character varying, p_patronymic character varying) OWNER TO postgres;

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
DECLARE
    v_invoice_id INTEGER;
    v_counteragent_id INTEGER;
    v_detail_id INTEGER;
    v_employee_id INTEGER;
    v_type_invoice BOOLEAN;
    v_status BOOLEAN;
BEGIN
    -- 1. Проверка и получение ID контрагента
    SELECT counteragent_id INTO v_counteragent_id 
    FROM counteragent 
    WHERE counteragent_name = NEW.counteragent_name;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Контрагент с именем % не найден', NEW.counteragent_name;
    END IF;

    -- 2. Преобразование текстовых значений в boolean
    IF NEW.type_invoice_text IS NOT NULL THEN
        v_type_invoice := convert_text_to_boolean(NEW.type_invoice_text, 'type');
    ELSE
        v_type_invoice := COALESCE(NEW.type_invoice_bool, FALSE);
    END IF;
    
    IF NEW.status_text IS NOT NULL THEN
        v_status := convert_text_to_boolean(NEW.status_text, 'status');
    ELSE
        v_status := COALESCE(NEW.status_bool, FALSE);
    END IF;

    -- 3. Обработка накладной (создание или обновление)
    IF NEW.invoice_id IS NOT NULL THEN
        -- Проверяем существование накладной
        PERFORM 1 FROM invoice WHERE invoice_id = NEW.invoice_id;
        
        IF FOUND THEN
            -- Обновляем существующую накладную
            UPDATE invoice SET
                counteragentID = v_counteragent_id,
                date_time = NEW.date_time,
                type_invoice = v_type_invoice,
                status = v_status
            WHERE invoice_id = NEW.invoice_id;
            
            v_invoice_id := NEW.invoice_id;
        ELSE
            -- Создаем новую накладную с указанным ID
            INSERT INTO invoice (invoice_id, counteragentID, date_time, type_invoice, status)
            VALUES (NEW.invoice_id, v_counteragent_id, NEW.date_time, v_type_invoice, v_status)
            RETURNING invoice_id INTO v_invoice_id;
        END IF;
    ELSE
        -- Создаем новую накладную без указания ID
        INSERT INTO invoice (counteragentID, date_time, type_invoice, status)
        VALUES (v_counteragent_id, NEW.date_time, v_type_invoice, v_status)
        RETURNING invoice_id INTO v_invoice_id;
    END IF;
    
    -- 4. Получаем ID детали
    SELECT detail_id INTO v_detail_id 
    FROM details 
    WHERE type_detail = NEW.type_detail;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Деталь типа % не найдена', NEW.type_detail;
    END IF;
    
    -- 5. Добавляем/обновляем деталь в накладной
    INSERT INTO invoice_detail (invoiceID, detailID, quantity)
    VALUES (v_invoice_id, v_detail_id, NEW.quantity)
    ON CONFLICT (invoiceID, detailID) 
    DO UPDATE SET quantity = invoice_detail.quantity + NEW.quantity;
    
    -- 6. Получаем ID сотрудника
    v_employee_id := get_employee_id(
        NEW.responsible_last_name, 
        NEW.responsible_first_name, 
        NEW.responsible_patronymic
    );
    
    -- 7. Связываем сотрудника с накладной
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (v_invoice_id, v_employee_id, v_employee_id, NOW())
    ON CONFLICT (invoiceID, responsible) DO NOTHING;
    
    -- 8. Возвращаем результат
    NEW.invoice_id := v_invoice_id;
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
    v_updated BOOLEAN := FALSE;
BEGIN
    -- 1. Если обновляется тип накладной (через текстовое поле)
    IF NEW.type_invoice_text IS DISTINCT FROM OLD.type_invoice_text THEN
        UPDATE invoice SET 
            type_invoice = convert_text_to_boolean(NEW.type_invoice_text, 'type')
        WHERE invoice_id = NEW.invoice_id;
        v_updated := TRUE;
    END IF;
    
    -- 2. Если обновляется статус (через текстовое поле)
    IF NEW.status_text IS DISTINCT FROM OLD.status_text THEN
        UPDATE invoice SET 
            status = convert_text_to_boolean(NEW.status_text, 'status')
        WHERE invoice_id = NEW.invoice_id;
        v_updated := TRUE;
    END IF;
    
    -- 3. Проверяем, что не пытаются изменить другие поля
    IF NOT v_updated AND (
        NEW.invoice_id IS DISTINCT FROM OLD.invoice_id OR
        NEW.counteragent_name IS DISTINCT FROM OLD.counteragent_name OR
        NEW.date_time IS DISTINCT FROM OLD.date_time OR
        NEW.type_detail IS DISTINCT FROM OLD.type_detail OR
        NEW.quantity IS DISTINCT FROM OLD.quantity OR
        NEW.responsible_last_name IS DISTINCT FROM OLD.responsible_last_name OR
        NEW.responsible_first_name IS DISTINCT FROM OLD.responsible_first_name OR
        NEW.responsible_patronymic IS DISTINCT FROM OLD.responsible_patronymic
    ) THEN
        RAISE EXCEPTION 'Разрешено обновлять только поля type_invoice_text и status_text';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_invoice_details_view() OWNER TO postgres;

--
-- Name: update_invoice_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_invoice_status() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Разрешаем обновлять только поле status
    IF TG_OP = 'UPDATE' AND (
        OLD.invoice_id IS DISTINCT FROM NEW.invoice_id OR
        OLD.counteragent_name IS DISTINCT FROM NEW.counteragent_name OR
        OLD.date_time IS DISTINCT FROM NEW.date_time OR
        OLD.type_invoice IS DISTINCT FROM NEW.type_invoice OR
        OLD.type_detail IS DISTINCT FROM NEW.type_detail OR
        OLD.quantity IS DISTINCT FROM NEW.quantity OR
        OLD.responsible_last_name IS DISTINCT FROM NEW.responsible_last_name OR
        OLD.responsible_first_name IS DISTINCT FROM NEW.responsible_first_name OR
        OLD.responsible_patronymic IS DISTINCT FROM NEW.responsible_patronymic OR
        OLD.responsible_id IS DISTINCT FROM NEW.responsible_id
    ) THEN
        RAISE EXCEPTION 'Разрешено обновлять только поле status. Попытка изменить другие поля запрещена.';
    END IF;
    
    -- Проверяем, что статус действительно изменился
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW; -- Ничего не делаем, если статус не изменился
    END IF;
    
    -- Обновляем статус в основной таблице
    UPDATE invoice SET status = NEW.status 
    WHERE invoice_id = NEW.invoice_id;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_invoice_status() OWNER TO postgres;

--
-- Name: update_warehouse_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_warehouse_details_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_warehouse_details_view() OWNER TO postgres;

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
        CASE
            WHEN inv.type_invoice THEN 'Выгрузка'::text
            ELSE 'Отгрузка'::text
        END AS type_invoice_text,
        CASE
            WHEN inv.status THEN 'Завершено'::text
            ELSE 'В процессе'::text
        END AS status_text,
    det.type_detail,
    invd.quantity,
    emp.last_name AS responsible_last_name,
    emp.first_name AS responsible_first_name,
    emp.patronymic AS responsible_patronymic,
    emp.employee_id AS responsible_id,
    inv.status AS status_bool,
    inv.type_invoice AS type_invoice_bool
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
7	пример	пример	1234567890	пример
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
12	6	3	Колесо
14	8	5	Новая деталь
15	8	2.5	Фары
16	9	5	Новая деталь
17	10	5	Новая деталь
18	10	5.9	Коробка передач
19	11	5	Новая деталь
20	12	5	Новая деталь
21	12	5.9	Коробка передач
22	13	5	Новая деталь
23	14	5	Новая деталь
24	14	5.9	Коробка передач
25	15	2	Диски
13	7	5	Новая деталь
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
1	7	2025-03-25 10:54:00	f	t
29	7	2025-03-25 10:00:00	f	t
\.


--
-- Data for Name: invoice_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_detail (invoiceid, detailid, quantity) FROM stdin;
2	2	5
3	3	20
4	4	7
5	5	15
1	12	100
29	1	10
\.


--
-- Data for Name: invoice_employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_employee (invoiceid, responsible, granted_access, when_granted) FROM stdin;
2	3	4	2025-03-02 10:35:00
3	2	5	2025-03-03 14:50:00
4	4	1	2025-03-04 11:25:00
5	5	3	2025-03-05 15:05:00
1	1	1	2025-03-26 01:13:16.977394
29	1	1	2025-03-26 01:48:36.553528
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
12	shelf	INSERT	6	2025-03-24 23:47:23.823603	\N	{"rackid": 1, "shelf_id": 6, "shelf_number": 200}
13	details	INSERT	11	2025-03-24 23:47:23.823603	\N	{"weight": 5, "shelfid": 6, "detail_id": 11, "type_detail": "Новая деталь"}
14	details	INSERT	12	2025-03-24 23:47:23.823603	\N	{"weight": 3, "shelfid": 6, "detail_id": 12, "type_detail": "Колесо"}
15	rack	INSERT	6	2025-03-24 23:48:45.999284	\N	{"roomid": 1, "rack_id": 6, "rack_number": 20}
16	shelf	INSERT	7	2025-03-24 23:48:45.999284	\N	{"rackid": 6, "shelf_id": 7, "shelf_number": 1}
17	details	INSERT	13	2025-03-24 23:48:45.999284	\N	{"weight": 5, "shelfid": 7, "detail_id": 13, "type_detail": "Новая деталь"}
18	shelf	INSERT	8	2025-03-24 23:48:45.999284	\N	{"rackid": 6, "shelf_id": 8, "shelf_number": 100}
19	details	INSERT	14	2025-03-24 23:48:45.999284	\N	{"weight": 5, "shelfid": 8, "detail_id": 14, "type_detail": "Новая деталь"}
20	details	INSERT	15	2025-03-24 23:48:45.999284	\N	{"weight": 2.5, "shelfid": 8, "detail_id": 15, "type_detail": "Фары"}
21	room	INSERT	6	2025-03-24 23:49:17.109634	\N	{"room_id": 6, "room_number": 2, "warehouseid": 1}
22	rack	INSERT	7	2025-03-24 23:49:17.109634	\N	{"roomid": 6, "rack_id": 7, "rack_number": 1}
23	shelf	INSERT	9	2025-03-24 23:49:17.109634	\N	{"rackid": 7, "shelf_id": 9, "shelf_number": 1}
24	details	INSERT	16	2025-03-24 23:49:17.109634	\N	{"weight": 5, "shelfid": 9, "detail_id": 16, "type_detail": "Новая деталь"}
25	shelf	INSERT	10	2025-03-24 23:49:17.109634	\N	{"rackid": 7, "shelf_id": 10, "shelf_number": 100}
26	details	INSERT	17	2025-03-24 23:49:17.109634	\N	{"weight": 5, "shelfid": 10, "detail_id": 17, "type_detail": "Новая деталь"}
27	details	INSERT	18	2025-03-24 23:49:17.109634	\N	{"weight": 5.9, "shelfid": 10, "detail_id": 18, "type_detail": "Коробка передач"}
28	rack	INSERT	8	2025-03-24 23:49:20.406536	\N	{"roomid": 2, "rack_id": 8, "rack_number": 1}
29	shelf	INSERT	11	2025-03-24 23:49:20.406536	\N	{"rackid": 8, "shelf_id": 11, "shelf_number": 1}
30	details	INSERT	19	2025-03-24 23:49:20.406536	\N	{"weight": 5, "shelfid": 11, "detail_id": 19, "type_detail": "Новая деталь"}
31	shelf	INSERT	12	2025-03-24 23:49:20.406536	\N	{"rackid": 8, "shelf_id": 12, "shelf_number": 100}
32	details	INSERT	20	2025-03-24 23:49:20.406536	\N	{"weight": 5, "shelfid": 12, "detail_id": 20, "type_detail": "Новая деталь"}
33	details	INSERT	21	2025-03-24 23:49:20.406536	\N	{"weight": 5.9, "shelfid": 12, "detail_id": 21, "type_detail": "Коробка передач"}
34	room	INSERT	7	2025-03-24 23:49:22.045398	\N	{"room_id": 7, "room_number": 2, "warehouseid": 3}
35	rack	INSERT	9	2025-03-24 23:49:22.045398	\N	{"roomid": 7, "rack_id": 9, "rack_number": 1}
36	shelf	INSERT	13	2025-03-24 23:49:22.045398	\N	{"rackid": 9, "shelf_id": 13, "shelf_number": 1}
37	details	INSERT	22	2025-03-24 23:49:22.045398	\N	{"weight": 5, "shelfid": 13, "detail_id": 22, "type_detail": "Новая деталь"}
38	shelf	INSERT	14	2025-03-24 23:49:22.045398	\N	{"rackid": 9, "shelf_id": 14, "shelf_number": 100}
39	details	INSERT	23	2025-03-24 23:49:22.045398	\N	{"weight": 5, "shelfid": 14, "detail_id": 23, "type_detail": "Новая деталь"}
40	details	INSERT	24	2025-03-24 23:49:22.045398	\N	{"weight": 5.9, "shelfid": 14, "detail_id": 24, "type_detail": "Коробка передач"}
41	shelf	INSERT	15	2025-03-24 23:52:55.531312	\N	{"rackid": 2, "shelf_id": 15, "shelf_number": 100}
42	details	INSERT	25	2025-03-24 23:52:55.531312	\N	{"weight": 2, "shelfid": 15, "detail_id": 25, "type_detail": "Диски"}
43	details	DELETE	11	2025-03-25 00:04:25.983578	{"weight": 5, "shelfid": 6, "detail_id": 11, "type_detail": "Новая деталь"}	\N
44	details	UPDATE	13	2025-03-25 00:09:40.216556	{"weight": 5, "shelfid": 7, "detail_id": 13, "type_detail": "Новая деталь"}	{"weight": 5, "shelfid": 7, "detail_id": 13, "type_detail": "Новая деталь"}
45	shelf	UPDATE	7	2025-03-25 00:09:40.216556	{"rackid": 6, "shelf_id": 7, "shelf_number": 1}	{"rackid": 6, "shelf_id": 7, "shelf_number": 100}
46	rack	UPDATE	6	2025-03-25 00:09:40.216556	{"roomid": 1, "rack_id": 6, "rack_number": 20}	{"roomid": 1, "rack_id": 6, "rack_number": 20}
47	room	UPDATE	1	2025-03-25 00:09:40.216556	{"room_id": 1, "room_number": 1, "warehouseid": 1}	{"room_id": 1, "room_number": 1, "warehouseid": 1}
48	warehouse	UPDATE	1	2025-03-25 00:09:40.216556	{"address": "ул. Дубовая, 1234, Город A", "warehouse_id": 1, "warehouse_number": 101}	{"address": "ул. Дубовая, 1234, Город A", "warehouse_id": 1, "warehouse_number": 101}
49	counteragent	INSERT	6	2025-03-25 01:12:01.666795	\N	{"address": "ул. Водная, 15, город Азов", "phone_number": 89613039295, "contact_person": "Егор Егорович", "counteragent_id": 6, "counteragent_name": "ООО \\"КарМоторс\\""}
50	counteragent	UPDATE	6	2025-03-25 01:17:16.463252	{"address": "ул. Водная, 15, город Азов", "phone_number": 89613039295, "contact_person": "Егор Егорович", "counteragent_id": 6, "counteragent_name": "ООО \\"КарМоторс\\""}	{"address": "ул. Водная, 15, город Азов", "phone_number": 89603039295, "contact_person": "Егор Егорович", "counteragent_id": 6, "counteragent_name": "ООО \\"КарМоторс\\""}
51	counteragent	DELETE	6	2025-03-25 01:17:31.489232	{"address": "ул. Водная, 15, город Азов", "phone_number": 89603039295, "contact_person": "Егор Егорович", "counteragent_id": 6, "counteragent_name": "ООО \\"КарМоторс\\""}	\N
52	employee	INSERT	9	2025-03-25 01:17:38.783613	\N	{"last_name": "Богданов", "first_name": "Богдан", "patronymic": "Богданович", "employee_id": 9, "employee_role": "Менеджер склада"}
53	employee	UPDATE	9	2025-03-25 01:18:54.032937	{"last_name": "Богданов", "first_name": "Богдан", "patronymic": "Богданович", "employee_id": 9, "employee_role": "Менеджер склада"}	{"last_name": "Богданов", "first_name": "Богдан", "patronymic": "Богданович", "employee_id": 9, "employee_role": "Кладовщик"}
54	employee	DELETE	9	2025-03-25 01:19:04.290375	{"last_name": "Богданов", "first_name": "Богдан", "patronymic": "Богданович", "employee_id": 9, "employee_role": "Кладовщик"}	\N
70	invoice_detail	DELETE	1	2025-03-25 22:21:29.934388	{"detailid": 1, "quantity": 10, "invoiceid": 1}	\N
71	invoice_detail	DELETE	1	2025-03-25 22:21:29.934388	{"detailid": 5, "quantity": 10, "invoiceid": 1}	\N
72	invoice_employee	DELETE	1	2025-03-25 22:21:29.934388	{"invoiceid": 1, "responsible": 1, "when_granted": "2025-03-01T09:05:00", "granted_access": 2}	\N
73	invoice	DELETE	1	2025-03-25 22:21:29.934388	{"status": false, "date_time": "2025-03-01T09:00:00", "invoice_id": 1, "type_invoice": true, "counteragentid": 1}	\N
74	counteragent	INSERT	7	2025-03-26 00:07:31.777609	\N	{"address": "пример", "phone_number": 1234567890, "contact_person": "пример", "counteragent_id": 7, "counteragent_name": "пример"}
108	invoice	INSERT	1	2025-03-26 01:13:16.977394	\N	{"status": false, "date_time": "2025-03-25T10:54:00", "invoice_id": 1, "type_invoice": false, "counteragentid": 7}
109	invoice_detail	INSERT	1	2025-03-26 01:13:16.977394	\N	{"detailid": 12, "quantity": 100, "invoiceid": 1}
110	invoice_employee	INSERT	1	2025-03-26 01:13:16.977394	\N	{"invoiceid": 1, "responsible": 1, "when_granted": "2025-03-26T01:13:16.977394", "granted_access": 1}
112	invoice	UPDATE	1	2025-03-26 01:23:28.286158	{"status": false, "date_time": "2025-03-25T10:54:00", "invoice_id": 1, "type_invoice": false, "counteragentid": 7}	{"status": true, "date_time": "2025-03-25T10:54:00", "invoice_id": 1, "type_invoice": false, "counteragentid": 7}
114	invoice	INSERT	29	2025-03-26 01:48:36.553528	\N	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": true, "counteragentid": 7}
115	invoice_detail	INSERT	29	2025-03-26 01:48:36.553528	\N	{"detailid": 1, "quantity": 10, "invoiceid": 29}
116	invoice_employee	INSERT	29	2025-03-26 01:48:36.553528	\N	{"invoiceid": 29, "responsible": 1, "when_granted": "2025-03-26T01:48:36.553528", "granted_access": 1}
117	invoice	UPDATE	29	2025-03-26 01:49:40.719115	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": true, "counteragentid": 7}	{"status": true, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": true, "counteragentid": 7}
118	invoice	UPDATE	29	2025-03-26 01:55:20.459669	{"status": true, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": true, "counteragentid": 7}	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": true, "counteragentid": 7}
119	invoice	UPDATE	29	2025-03-26 02:00:08.61966	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": true, "counteragentid": 7}	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}
120	invoice	UPDATE	29	2025-03-26 02:01:35.525554	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}	{"status": true, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}
121	invoice	INSERT	30	2025-03-26 02:02:43.0279	\N	{"status": false, "date_time": "2025-03-26T10:00:00", "invoice_id": 30, "type_invoice": true, "counteragentid": 7}
122	invoice_detail	INSERT	30	2025-03-26 02:02:43.0279	\N	{"detailid": 4, "quantity": 1, "invoiceid": 30}
123	invoice_employee	INSERT	30	2025-03-26 02:02:43.0279	\N	{"invoiceid": 30, "responsible": 1, "when_granted": "2025-03-26T02:02:43.0279", "granted_access": 1}
124	invoice	UPDATE	29	2025-03-26 02:17:17.745391	{"status": true, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}
125	invoice	UPDATE	29	2025-03-26 02:19:12.934799	{"status": false, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}	{"status": true, "date_time": "2025-03-25T10:00:00", "invoice_id": 29, "type_invoice": false, "counteragentid": 7}
126	invoice	UPDATE	30	2025-03-26 02:19:27.857438	{"status": false, "date_time": "2025-03-26T10:00:00", "invoice_id": 30, "type_invoice": true, "counteragentid": 7}	{"status": false, "date_time": "2025-03-26T10:00:00", "invoice_id": 30, "type_invoice": false, "counteragentid": 7}
127	invoice	UPDATE	30	2025-03-26 02:19:38.738196	{"status": false, "date_time": "2025-03-26T10:00:00", "invoice_id": 30, "type_invoice": false, "counteragentid": 7}	{"status": true, "date_time": "2025-03-26T10:00:00", "invoice_id": 30, "type_invoice": false, "counteragentid": 7}
128	invoice_employee	DELETE	30	2025-03-26 02:19:48.506713	{"invoiceid": 30, "responsible": 1, "when_granted": "2025-03-26T02:02:43.0279", "granted_access": 1}	\N
129	invoice_detail	DELETE	30	2025-03-26 02:19:48.506713	{"detailid": 4, "quantity": 1, "invoiceid": 30}	\N
130	invoice	DELETE	30	2025-03-26 02:19:48.506713	{"status": true, "date_time": "2025-03-26T10:00:00", "invoice_id": 30, "type_invoice": false, "counteragentid": 7}	\N
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
7	6	1
8	2	1
9	7	1
6	1	20
\.


--
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.room (room_id, warehouseid, room_number) FROM stdin;
2	2	2
3	3	3
4	4	4
5	5	5
6	1	2
7	3	2
1	1	1
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
6	1	200
8	6	100
9	7	1
10	7	100
11	8	1
12	8	100
13	9	1
14	9	100
15	2	100
7	6	100
\.


--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.warehouse (warehouse_id, warehouse_number, address) FROM stdin;
2	102	ул. Кленовая, 5678, Город B
3	103	ул. Сосновая, 9101, Город C
4	104	ул. Кедровая, 1213, Город D
5	105	ул. Вязовая, 1415, Город E
1	101	ул. Дубовая, 1234, Город A
\.


--
-- Name: counteragent_counteragent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.counteragent_counteragent_id_seq', 7, true);


--
-- Name: details_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.details_detail_id_seq', 25, true);


--
-- Name: details_shelfid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.details_shelfid_seq', 1, false);


--
-- Name: employee_employee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.employee_employee_id_seq', 9, true);


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

SELECT pg_catalog.setval('public.invoice_invoice_id_seq', 30, true);


--
-- Name: log_table_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.log_table_log_id_seq', 130, true);


--
-- Name: rack_rack_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rack_rack_id_seq', 9, true);


--
-- Name: rack_roomid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rack_roomid_seq', 1, false);


--
-- Name: room_room_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.room_room_id_seq', 7, true);


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

SELECT pg_catalog.setval('public.shelf_shelf_id_seq', 15, true);


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
-- Name: invoice_detail invoice_detail_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_detail
    ADD CONSTRAINT invoice_detail_unique UNIQUE (invoiceid, detailid);


--
-- Name: invoice_employee invoice_employee_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_unique UNIQUE (invoiceid, responsible);


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
-- Name: warehouse_details_view instead_of_update_warehouse_details_view; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER instead_of_update_warehouse_details_view INSTEAD OF UPDATE ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.update_warehouse_details_view();


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
-- Name: invoice_details_view invoice_details_view_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER invoice_details_view_insert INSTEAD OF INSERT ON public.invoice_details_view FOR EACH ROW EXECUTE FUNCTION public.insert_invoice_details_view();


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
-- Name: invoice trg_delete_invoice_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_delete_invoice_details AFTER DELETE ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.delete_invoice_details_view();


--
-- Name: warehouse trg_delete_related_data; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_delete_related_data BEFORE DELETE ON public.warehouse FOR EACH ROW EXECUTE FUNCTION public.delete_related_data();


--
-- Name: warehouse_details_view trigger_delete_warehouse_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_delete_warehouse_details INSTEAD OF DELETE ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.delete_warehouse_details();


--
-- Name: warehouse_details_view trigger_insert_warehouse_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_insert_warehouse_details INSTEAD OF INSERT ON public.warehouse_details_view FOR EACH ROW EXECUTE FUNCTION public.insert_into_warehouse_details();


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
-- Name: FUNCTION convert_text_to_boolean(text_value text, field_type text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.convert_text_to_boolean(text_value text, field_type text) TO warehouse_owner;


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
-- Name: FUNCTION get_employee_id(p_last_name character varying, p_first_name character varying, p_patronymic character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_employee_id(p_last_name character varying, p_first_name character varying, p_patronymic character varying) TO warehouse_owner;
GRANT ALL ON FUNCTION public.get_employee_id(p_last_name character varying, p_first_name character varying, p_patronymic character varying) TO warehouse_manager;


--
-- Name: FUNCTION insert_into_warehouse_details(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_into_warehouse_details() TO warehouse_owner;


--
-- Name: FUNCTION insert_invoice_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_invoice_details_view() TO warehouse_owner;
GRANT ALL ON FUNCTION public.insert_invoice_details_view() TO warehouse_manager;


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
-- Name: FUNCTION update_invoice_status(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_invoice_status() TO warehouse_owner;


--
-- Name: FUNCTION update_warehouse_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_warehouse_details_view() TO warehouse_owner;


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

GRANT SELECT,UPDATE ON TABLE public.invoice TO warehouse_clerk;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice TO warehouse_owner;


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
GRANT SELECT,UPDATE ON TABLE public.invoice_details_view TO warehouse_clerk;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice_details_view TO warehouse_manager;


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
GRANT SELECT,USAGE ON SEQUENCE public.rack_rack_id_seq TO warehouse_clerk;


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
GRANT SELECT,USAGE ON SEQUENCE public.room_room_id_seq TO warehouse_clerk;


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
GRANT SELECT,USAGE ON SEQUENCE public.shelf_shelf_id_seq TO warehouse_clerk;


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

