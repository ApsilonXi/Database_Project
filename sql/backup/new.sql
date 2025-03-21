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
-- Name: insert_invoice_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_invoice_details_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.insert_invoice_details_view() OWNER TO postgres;

--
-- Name: log_invoice_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_invoice_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Записываем в лог старое и новое значение статуса и даты-времени
    INSERT INTO invoice_log (invoice_id, old_status, new_status, old_date_time, new_date_time, changed_by)
    VALUES (OLD.invoice_id, OLD.status, NEW.status, OLD.date_time, NEW.date_time, current_user);
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_invoice_changes() OWNER TO postgres;

--
-- Name: update_invoice_details_view(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_invoice_details_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_invoice_details_view() OWNER TO postgres;

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
    inv.counteragentid,
    inv.date_time,
    inv.type_invoice,
    inv.status,
    invd.detailid,
    invd.quantity,
    emp.last_name AS responsible_last_name,
    emp.first_name AS responsible_first_name,
    emp.patronymic AS responsible_patronymic
   FROM ((((public.invoice inv
     JOIN public.invoice_detail invd ON ((inv.invoice_id = invd.invoiceid)))
     JOIN public.details det ON ((invd.detailid = det.detail_id)))
     JOIN public.invoice_employee inv_emp ON ((inv.invoice_id = inv_emp.invoiceid)))
     JOIN public.employee emp ON ((inv_emp.responsible = emp.employee_id)));


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
-- Name: invoice_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_log (
    log_id integer NOT NULL,
    invoice_id integer,
    old_status boolean,
    new_status boolean,
    old_date_time timestamp without time zone,
    new_date_time timestamp without time zone,
    changed_by text,
    change_time timestamp without time zone DEFAULT now()
);


ALTER TABLE public.invoice_log OWNER TO postgres;

--
-- Name: invoice_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_log_log_id_seq OWNER TO postgres;

--
-- Name: invoice_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_log_log_id_seq OWNED BY public.invoice_log.log_id;


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
-- Name: invoice_log log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_log ALTER COLUMN log_id SET DEFAULT nextval('public.invoice_log_log_id_seq'::regclass);


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
1	1	12.5	Двигатель
2	2	5	Тормозные колодки
3	3	20.7	Подвеска
4	4	7.3	Фары
5	5	15.2	Шины
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
1	1	2025-03-01 09:00:00	f	t
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
1	1	2	2025-03-01 09:05:00
2	3	4	2025-03-02 10:35:00
3	2	5	2025-03-03 14:50:00
4	4	1	2025-03-04 11:25:00
5	5	3	2025-03-05 15:05:00
\.


--
-- Data for Name: invoice_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_log (log_id, invoice_id, old_status, new_status, old_date_time, new_date_time, changed_by, change_time) FROM stdin;
6	1	f	t	2025-03-01 09:00:00	2025-03-01 09:00:00	ivanov_ii	2025-03-18 01:21:46.519759
7	1	t	t	2025-03-01 09:00:00	2025-03-01 09:00:00	volkov_aa	2025-03-18 01:23:39.472607
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

SELECT pg_catalog.setval('public.details_detail_id_seq', 9, true);


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
-- Name: invoice_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_log_log_id_seq', 7, true);


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
-- Name: invoice_log invoice_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_log
    ADD CONSTRAINT invoice_log_pkey PRIMARY KEY (log_id);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (invoice_id);


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
-- Name: invoice trg_log_invoice_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_log_invoice_changes AFTER UPDATE ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.log_invoice_changes();


--
-- Name: invoice trg_update_invoice_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_invoice_details AFTER UPDATE ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.update_invoice_details_view();


--
-- Name: shelf trg_update_shelfid_in_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_shelfid_in_details AFTER UPDATE ON public.shelf FOR EACH ROW EXECUTE FUNCTION public.update_shelfid_in_details();


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
-- Name: FUNCTION fill_invoice_detail(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fill_invoice_detail() TO warehouse_owner;


--
-- Name: FUNCTION fill_invoice_employee(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fill_invoice_employee() TO warehouse_owner;


--
-- Name: FUNCTION insert_invoice_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_invoice_details_view() TO warehouse_owner;


--
-- Name: FUNCTION log_invoice_changes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_invoice_changes() TO warehouse_owner;


--
-- Name: FUNCTION update_invoice_details_view(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_invoice_details_view() TO warehouse_owner;


--
-- Name: FUNCTION update_shelfid_in_details(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_shelfid_in_details() TO warehouse_owner;


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

GRANT SELECT,INSERT,UPDATE ON TABLE public.details TO warehouse_clerk;
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
-- Name: TABLE invoice_log; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.invoice_log TO warehouse_clerk;
GRANT SELECT,INSERT ON TABLE public.invoice_log TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice_log TO warehouse_owner;


--
-- Name: SEQUENCE invoice_log_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_clerk;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_owner;


--
-- Name: TABLE rack; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.rack TO warehouse_clerk;
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

GRANT SELECT,INSERT,UPDATE ON TABLE public.room TO warehouse_clerk;
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

GRANT SELECT,INSERT,UPDATE ON TABLE public.shelf TO warehouse_clerk;
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

GRANT SELECT,INSERT,UPDATE ON TABLE public.warehouse TO warehouse_clerk;
GRANT SELECT ON TABLE public.warehouse TO warehouse_owner;


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

