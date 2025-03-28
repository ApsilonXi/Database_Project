PGDMP  :    3                }            Warehouse_DB    17.4    17.4 �    P           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                           false            Q           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                           false            R           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                           false            S           1262    16746    Warehouse_DB    DATABASE     �   CREATE DATABASE "Warehouse_DB" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';
    DROP DATABASE "Warehouse_DB";
                     postgres    false            T           0    0    DATABASE "Warehouse_DB"    ACL     =   GRANT CONNECT ON DATABASE "Warehouse_DB" TO warehouse_owner;
                        postgres    false    4947            U           0    0    SCHEMA public    ACL     1   GRANT USAGE ON SCHEMA public TO warehouse_owner;
                        pg_database_owner    false    5            
           1255    17213    add_default_detail()    FUNCTION     i  CREATE FUNCTION public.add_default_detail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении новой полки автоматически добавляется одна деталь
    INSERT INTO details (shelfID, weight, type_detail) VALUES (NEW.shelf_id, 5.0, 'Новая деталь');
    RETURN NEW;
END;
$$;
 +   DROP FUNCTION public.add_default_detail();
       public               postgres    false            V           0    0    FUNCTION add_default_detail()    ACL     F   GRANT ALL ON FUNCTION public.add_default_detail() TO warehouse_owner;
          public               postgres    false    266                       1255    17207    add_default_rack()    FUNCTION     C  CREATE FUNCTION public.add_default_rack() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении новой комнаты автоматически создается первый стеллаж
    INSERT INTO rack (roomID, rack_number) VALUES (NEW.room_id, 1);
    RETURN NEW;
END;
$$;
 )   DROP FUNCTION public.add_default_rack();
       public               postgres    false            W           0    0    FUNCTION add_default_rack()    ACL     D   GRANT ALL ON FUNCTION public.add_default_rack() TO warehouse_owner;
          public               postgres    false    263                       1255    17205    add_default_room()    FUNCTION     Q  CREATE FUNCTION public.add_default_room() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении нового склада автоматически добавляется первая комната
    INSERT INTO room (warehouseID, room_number) VALUES (NEW.warehouse_id, 1);
    RETURN NEW;
END;
$$;
 )   DROP FUNCTION public.add_default_room();
       public               postgres    false            X           0    0    FUNCTION add_default_room()    ACL     D   GRANT ALL ON FUNCTION public.add_default_room() TO warehouse_owner;
          public               postgres    false    262            �            1255    17209    add_default_shelf()    FUNCTION     F  CREATE FUNCTION public.add_default_shelf() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При добавлении нового стеллажа автоматически создается первая полка
    INSERT INTO shelf (rackID, shelf_number) VALUES (NEW.rack_id, 1);
    RETURN NEW;
END;
$$;
 *   DROP FUNCTION public.add_default_shelf();
       public               postgres    false            Y           0    0    FUNCTION add_default_shelf()    ACL     E   GRANT ALL ON FUNCTION public.add_default_shelf() TO warehouse_owner;
          public               postgres    false    248            	           1255    17211    delete_related_data()    FUNCTION       CREATE FUNCTION public.delete_related_data() RETURNS trigger
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
 ,   DROP FUNCTION public.delete_related_data();
       public               postgres    false            Z           0    0    FUNCTION delete_related_data()    ACL     G   GRANT ALL ON FUNCTION public.delete_related_data() TO warehouse_owner;
          public               postgres    false    265                       1255    17203    fill_invoice_detail()    FUNCTION     �  CREATE FUNCTION public.fill_invoice_detail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
BEGIN
    -- Проверяем тип накладной
    IF NEW.type_invoice = true THEN
        -- Поставка: Добавляем деталь (например, тормозные колодки)
        INSERT INTO invoice_detail (invoiceID, detailID, quantity)
        VALUES (NEW.invoice_id,
                (SELECT detail_id FROM details WHERE type_detail = 'Тормозные колодки' LIMIT 1),
                10); 
    ELSE
        -- Отгрузка: Добавляем детали с другим типом
        INSERT INTO invoice_detail (invoiceID, detailID, quantity)
        VALUES (NEW.invoice_id,
                (SELECT detail_id FROM details WHERE type_detail = 'Отгрузка деталь' LIMIT 1),
                5);
    END IF;

    RETURN NEW;
END;
$$;
 ,   DROP FUNCTION public.fill_invoice_detail();
       public               postgres    false            [           0    0    FUNCTION fill_invoice_detail()    ACL     G   GRANT ALL ON FUNCTION public.fill_invoice_detail() TO warehouse_owner;
          public               postgres    false    264                       1255    17201    fill_invoice_employee()    FUNCTION     '  CREATE FUNCTION public.fill_invoice_employee() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Назначаем сотрудника, ответственного за накладную, по умолчанию (например, сотрудник с employee_id = 1)
    INSERT INTO invoice_employee (invoiceID, responsible, granted_access, when_granted)
    VALUES (NEW.invoice_id, 1, 2, now());  -- "granted_access" назначен сотруднику с employee_id = 2, время - текущее
    
    RETURN NEW;
END;
$$;
 .   DROP FUNCTION public.fill_invoice_employee();
       public               postgres    false            \           0    0     FUNCTION fill_invoice_employee()    ACL     I   GRANT ALL ON FUNCTION public.fill_invoice_employee() TO warehouse_owner;
          public               postgres    false    261                       1255    17199    log_invoice_changes()    FUNCTION     �  CREATE FUNCTION public.log_invoice_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Записываем в лог старое и новое значение статуса и даты-времени
    INSERT INTO invoice_log (invoice_id, old_status, new_status, old_date_time, new_date_time, changed_by)
    VALUES (OLD.invoice_id, OLD.status, NEW.status, OLD.date_time, NEW.date_time, current_user);
    
    RETURN NEW;
END;
$$;
 ,   DROP FUNCTION public.log_invoice_changes();
       public               postgres    false            ]           0    0    FUNCTION log_invoice_changes()    ACL     G   GRANT ALL ON FUNCTION public.log_invoice_changes() TO warehouse_owner;
          public               postgres    false    260            �            1255    17215    update_shelfid_in_details()    FUNCTION       CREATE FUNCTION public.update_shelfid_in_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Обновление связанных записей в details
    UPDATE details SET shelfID = NEW.shelf_id WHERE shelfID = OLD.shelf_id;
    RETURN NEW;
END;
$$;
 2   DROP FUNCTION public.update_shelfid_in_details();
       public               postgres    false            ^           0    0 $   FUNCTION update_shelfid_in_details()    ACL     M   GRANT ALL ON FUNCTION public.update_shelfid_in_details() TO warehouse_owner;
          public               postgres    false    247            �            1259    17115    counteragent    TABLE     �   CREATE TABLE public.counteragent (
    counteragent_id integer NOT NULL,
    counteragent_name character varying(128) NOT NULL,
    contact_person character varying(128) NOT NULL,
    phone_number bigint NOT NULL,
    address text NOT NULL
);
     DROP TABLE public.counteragent;
       public         heap r       postgres    false            _           0    0    TABLE counteragent    ACL     �   GRANT SELECT ON TABLE public.counteragent TO warehouse_manager;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.counteragent TO warehouse_owner;
          public               postgres    false    232            �            1259    17114     counteragent_counteragent_id_seq    SEQUENCE     �   CREATE SEQUENCE public.counteragent_counteragent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.counteragent_counteragent_id_seq;
       public               postgres    false    232            `           0    0     counteragent_counteragent_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.counteragent_counteragent_id_seq OWNED BY public.counteragent.counteragent_id;
          public               postgres    false    231            a           0    0 )   SEQUENCE counteragent_counteragent_id_seq    ACL     [   GRANT SELECT,USAGE ON SEQUENCE public.counteragent_counteragent_id_seq TO warehouse_owner;
          public               postgres    false    231            �            1259    17100    details    TABLE     �   CREATE TABLE public.details (
    detail_id integer NOT NULL,
    shelfid integer NOT NULL,
    weight double precision NOT NULL,
    type_detail text NOT NULL
);
    DROP TABLE public.details;
       public         heap r       postgres    false            b           0    0    TABLE details    ACL     �   GRANT SELECT,INSERT,UPDATE ON TABLE public.details TO warehouse_clerk;
GRANT SELECT ON TABLE public.details TO warehouse_manager;
GRANT SELECT ON TABLE public.details TO warehouse_owner;
          public               postgres    false    230            �            1259    17098    details_detail_id_seq    SEQUENCE     �   CREATE SEQUENCE public.details_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.details_detail_id_seq;
       public               postgres    false    230            c           0    0    details_detail_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE public.details_detail_id_seq OWNED BY public.details.detail_id;
          public               postgres    false    228            d           0    0    SEQUENCE details_detail_id_seq    ACL     �   GRANT SELECT,USAGE ON SEQUENCE public.details_detail_id_seq TO warehouse_clerk;
GRANT SELECT,USAGE ON SEQUENCE public.details_detail_id_seq TO warehouse_owner;
          public               postgres    false    228            �            1259    17099    details_shelfid_seq    SEQUENCE     �   CREATE SEQUENCE public.details_shelfid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.details_shelfid_seq;
       public               postgres    false    230            e           0    0    details_shelfid_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.details_shelfid_seq OWNED BY public.details.shelfid;
          public               postgres    false    229            f           0    0    SEQUENCE details_shelfid_seq    ACL     N   GRANT SELECT,USAGE ON SEQUENCE public.details_shelfid_seq TO warehouse_owner;
          public               postgres    false    229            �            1259    17155    employee    TABLE       CREATE TABLE public.employee (
    employee_id integer NOT NULL,
    employee_role character varying(25) NOT NULL,
    last_name character varying(35) NOT NULL,
    first_name character varying(35) NOT NULL,
    patronymic character varying(35) NOT NULL
);
    DROP TABLE public.employee;
       public         heap r       postgres    false            g           0    0    TABLE employee    ACL     O   GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.employee TO warehouse_owner;
          public               postgres    false    240            �            1259    17154    employee_employee_id_seq    SEQUENCE     �   CREATE SEQUENCE public.employee_employee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.employee_employee_id_seq;
       public               postgres    false    240            h           0    0    employee_employee_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.employee_employee_id_seq OWNED BY public.employee.employee_id;
          public               postgres    false    239            i           0    0 !   SEQUENCE employee_employee_id_seq    ACL     �   GRANT SELECT,USAGE ON SEQUENCE public.employee_employee_id_seq TO warehouse_owner;
GRANT SELECT,USAGE ON SEQUENCE public.employee_employee_id_seq TO warehouse_manager;
          public               postgres    false    239            �            1259    17125    invoice    TABLE     �   CREATE TABLE public.invoice (
    invoice_id integer NOT NULL,
    counteragentid integer NOT NULL,
    date_time timestamp without time zone NOT NULL,
    type_invoice boolean NOT NULL,
    status boolean NOT NULL
);
    DROP TABLE public.invoice;
       public         heap r       postgres    false            j           0    0    TABLE invoice    ACL     �   GRANT SELECT ON TABLE public.invoice TO warehouse_clerk;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice TO warehouse_owner;
          public               postgres    false    235            k           0    0    COLUMN invoice.status    ACL     A   GRANT UPDATE(status) ON TABLE public.invoice TO warehouse_clerk;
          public               postgres    false    235    4970            �            1259    17124    invoice_counteragentid_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_counteragentid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.invoice_counteragentid_seq;
       public               postgres    false    235            l           0    0    invoice_counteragentid_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.invoice_counteragentid_seq OWNED BY public.invoice.counteragentid;
          public               postgres    false    234            m           0    0 #   SEQUENCE invoice_counteragentid_seq    ACL     U   GRANT SELECT,USAGE ON SEQUENCE public.invoice_counteragentid_seq TO warehouse_owner;
          public               postgres    false    234            �            1259    17139    invoice_detail    TABLE     �   CREATE TABLE public.invoice_detail (
    invoiceid integer NOT NULL,
    detailid integer NOT NULL,
    quantity integer NOT NULL
);
 "   DROP TABLE public.invoice_detail;
       public         heap r       postgres    false            n           0    0    TABLE invoice_detail    ACL     �   GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice_detail TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice_detail TO warehouse_owner;
          public               postgres    false    238            �            1259    17138    invoice_detail_detailid_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_detail_detailid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.invoice_detail_detailid_seq;
       public               postgres    false    238            o           0    0    invoice_detail_detailid_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.invoice_detail_detailid_seq OWNED BY public.invoice_detail.detailid;
          public               postgres    false    237            p           0    0 $   SEQUENCE invoice_detail_detailid_seq    ACL     V   GRANT SELECT,USAGE ON SEQUENCE public.invoice_detail_detailid_seq TO warehouse_owner;
          public               postgres    false    237            �            1259    17137    invoice_detail_invoiceid_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_detail_invoiceid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.invoice_detail_invoiceid_seq;
       public               postgres    false    238            q           0    0    invoice_detail_invoiceid_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.invoice_detail_invoiceid_seq OWNED BY public.invoice_detail.invoiceid;
          public               postgres    false    236            r           0    0 %   SEQUENCE invoice_detail_invoiceid_seq    ACL     �   GRANT SELECT,USAGE ON SEQUENCE public.invoice_detail_invoiceid_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_detail_invoiceid_seq TO warehouse_owner;
          public               postgres    false    236            �            1259    17164    invoice_employee    TABLE     �   CREATE TABLE public.invoice_employee (
    invoiceid integer NOT NULL,
    responsible integer NOT NULL,
    granted_access integer NOT NULL,
    when_granted timestamp without time zone NOT NULL
);
 $   DROP TABLE public.invoice_employee;
       public         heap r       postgres    false            s           0    0    TABLE invoice_employee    ACL     �   GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoice_employee TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice_employee TO warehouse_owner;
          public               postgres    false    244            �            1259    17163 #   invoice_employee_granted_access_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_employee_granted_access_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.invoice_employee_granted_access_seq;
       public               postgres    false    244            t           0    0 #   invoice_employee_granted_access_seq    SEQUENCE OWNED BY     k   ALTER SEQUENCE public.invoice_employee_granted_access_seq OWNED BY public.invoice_employee.granted_access;
          public               postgres    false    243            u           0    0 ,   SEQUENCE invoice_employee_granted_access_seq    ACL     ^   GRANT SELECT,USAGE ON SEQUENCE public.invoice_employee_granted_access_seq TO warehouse_owner;
          public               postgres    false    243            �            1259    17161    invoice_employee_invoiceid_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_employee_invoiceid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.invoice_employee_invoiceid_seq;
       public               postgres    false    244            v           0    0    invoice_employee_invoiceid_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.invoice_employee_invoiceid_seq OWNED BY public.invoice_employee.invoiceid;
          public               postgres    false    241            w           0    0 '   SEQUENCE invoice_employee_invoiceid_seq    ACL     Y   GRANT SELECT,USAGE ON SEQUENCE public.invoice_employee_invoiceid_seq TO warehouse_owner;
          public               postgres    false    241            �            1259    17162     invoice_employee_responsible_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_employee_responsible_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.invoice_employee_responsible_seq;
       public               postgres    false    244            x           0    0     invoice_employee_responsible_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.invoice_employee_responsible_seq OWNED BY public.invoice_employee.responsible;
          public               postgres    false    242            y           0    0 )   SEQUENCE invoice_employee_responsible_seq    ACL     [   GRANT SELECT,USAGE ON SEQUENCE public.invoice_employee_responsible_seq TO warehouse_owner;
          public               postgres    false    242            �            1259    17123    invoice_invoice_id_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_invoice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.invoice_invoice_id_seq;
       public               postgres    false    235            z           0    0    invoice_invoice_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.invoice_invoice_id_seq OWNED BY public.invoice.invoice_id;
          public               postgres    false    233            {           0    0    SEQUENCE invoice_invoice_id_seq    ACL     �   GRANT SELECT,USAGE ON SEQUENCE public.invoice_invoice_id_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_invoice_id_seq TO warehouse_owner;
          public               postgres    false    233            �            1259    17186    invoice_log    TABLE     7  CREATE TABLE public.invoice_log (
    log_id integer NOT NULL,
    invoice_id integer,
    old_status boolean,
    new_status boolean,
    old_date_time timestamp without time zone,
    new_date_time timestamp without time zone,
    changed_by text,
    change_time timestamp without time zone DEFAULT now()
);
    DROP TABLE public.invoice_log;
       public         heap r       postgres    false            |           0    0    TABLE invoice_log    ACL     �   GRANT SELECT,INSERT ON TABLE public.invoice_log TO warehouse_clerk;
GRANT SELECT,INSERT ON TABLE public.invoice_log TO warehouse_manager;
GRANT SELECT ON TABLE public.invoice_log TO warehouse_owner;
          public               postgres    false    246            �            1259    17185    invoice_log_log_id_seq    SEQUENCE     �   CREATE SEQUENCE public.invoice_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.invoice_log_log_id_seq;
       public               postgres    false    246            }           0    0    invoice_log_log_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.invoice_log_log_id_seq OWNED BY public.invoice_log.log_id;
          public               postgres    false    245            ~           0    0    SEQUENCE invoice_log_log_id_seq    ACL     �   GRANT SELECT,USAGE ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_clerk;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_manager;
GRANT SELECT,USAGE ON SEQUENCE public.invoice_log_log_id_seq TO warehouse_owner;
          public               postgres    false    245            �            1259    17072    rack    TABLE     z   CREATE TABLE public.rack (
    rack_id integer NOT NULL,
    roomid integer NOT NULL,
    rack_number integer NOT NULL
);
    DROP TABLE public.rack;
       public         heap r       postgres    false                       0    0 
   TABLE rack    ACL     z   GRANT SELECT,INSERT,UPDATE ON TABLE public.rack TO warehouse_clerk;
GRANT SELECT ON TABLE public.rack TO warehouse_owner;
          public               postgres    false    224            �            1259    17070    rack_rack_id_seq    SEQUENCE     �   CREATE SEQUENCE public.rack_rack_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.rack_rack_id_seq;
       public               postgres    false    224            �           0    0    rack_rack_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.rack_rack_id_seq OWNED BY public.rack.rack_id;
          public               postgres    false    222            �           0    0    SEQUENCE rack_rack_id_seq    ACL     K   GRANT SELECT,USAGE ON SEQUENCE public.rack_rack_id_seq TO warehouse_owner;
          public               postgres    false    222            �            1259    17071    rack_roomid_seq    SEQUENCE     �   CREATE SEQUENCE public.rack_roomid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.rack_roomid_seq;
       public               postgres    false    224            �           0    0    rack_roomid_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.rack_roomid_seq OWNED BY public.rack.roomid;
          public               postgres    false    223            �           0    0    SEQUENCE rack_roomid_seq    ACL     J   GRANT SELECT,USAGE ON SEQUENCE public.rack_roomid_seq TO warehouse_owner;
          public               postgres    false    223            �            1259    17058    room    TABLE        CREATE TABLE public.room (
    room_id integer NOT NULL,
    warehouseid integer NOT NULL,
    room_number integer NOT NULL
);
    DROP TABLE public.room;
       public         heap r       postgres    false            �           0    0 
   TABLE room    ACL     z   GRANT SELECT,INSERT,UPDATE ON TABLE public.room TO warehouse_clerk;
GRANT SELECT ON TABLE public.room TO warehouse_owner;
          public               postgres    false    221            �            1259    17056    room_room_id_seq    SEQUENCE     �   CREATE SEQUENCE public.room_room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.room_room_id_seq;
       public               postgres    false    221            �           0    0    room_room_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.room_room_id_seq OWNED BY public.room.room_id;
          public               postgres    false    219            �           0    0    SEQUENCE room_room_id_seq    ACL     K   GRANT SELECT,USAGE ON SEQUENCE public.room_room_id_seq TO warehouse_owner;
          public               postgres    false    219            �            1259    17057    room_warehouseid_seq    SEQUENCE     �   CREATE SEQUENCE public.room_warehouseid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.room_warehouseid_seq;
       public               postgres    false    221            �           0    0    room_warehouseid_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.room_warehouseid_seq OWNED BY public.room.warehouseid;
          public               postgres    false    220            �           0    0    SEQUENCE room_warehouseid_seq    ACL     O   GRANT SELECT,USAGE ON SEQUENCE public.room_warehouseid_seq TO warehouse_owner;
          public               postgres    false    220            �            1259    17086    shelf    TABLE     }   CREATE TABLE public.shelf (
    shelf_id integer NOT NULL,
    rackid integer NOT NULL,
    shelf_number integer NOT NULL
);
    DROP TABLE public.shelf;
       public         heap r       postgres    false            �           0    0    TABLE shelf    ACL     |   GRANT SELECT,INSERT,UPDATE ON TABLE public.shelf TO warehouse_clerk;
GRANT SELECT ON TABLE public.shelf TO warehouse_owner;
          public               postgres    false    227            �            1259    17085    shelf_rackid_seq    SEQUENCE     �   CREATE SEQUENCE public.shelf_rackid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.shelf_rackid_seq;
       public               postgres    false    227            �           0    0    shelf_rackid_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.shelf_rackid_seq OWNED BY public.shelf.rackid;
          public               postgres    false    226            �           0    0    SEQUENCE shelf_rackid_seq    ACL     K   GRANT SELECT,USAGE ON SEQUENCE public.shelf_rackid_seq TO warehouse_owner;
          public               postgres    false    226            �            1259    17084    shelf_shelf_id_seq    SEQUENCE     �   CREATE SEQUENCE public.shelf_shelf_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.shelf_shelf_id_seq;
       public               postgres    false    227            �           0    0    shelf_shelf_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.shelf_shelf_id_seq OWNED BY public.shelf.shelf_id;
          public               postgres    false    225            �           0    0    SEQUENCE shelf_shelf_id_seq    ACL     M   GRANT SELECT,USAGE ON SEQUENCE public.shelf_shelf_id_seq TO warehouse_owner;
          public               postgres    false    225            �            1259    17048 	   warehouse    TABLE     �   CREATE TABLE public.warehouse (
    warehouse_id integer NOT NULL,
    warehouse_number integer NOT NULL,
    address text NOT NULL
);
    DROP TABLE public.warehouse;
       public         heap r       postgres    false            �           0    0    TABLE warehouse    ACL     �   GRANT SELECT,INSERT,UPDATE ON TABLE public.warehouse TO warehouse_clerk;
GRANT SELECT ON TABLE public.warehouse TO warehouse_owner;
          public               postgres    false    218            �            1259    17047    warehouse_warehouse_id_seq    SEQUENCE     �   CREATE SEQUENCE public.warehouse_warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.warehouse_warehouse_id_seq;
       public               postgres    false    218            �           0    0    warehouse_warehouse_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.warehouse_warehouse_id_seq OWNED BY public.warehouse.warehouse_id;
          public               postgres    false    217            �           0    0 #   SEQUENCE warehouse_warehouse_id_seq    ACL     U   GRANT SELECT,USAGE ON SEQUENCE public.warehouse_warehouse_id_seq TO warehouse_owner;
          public               postgres    false    217            o           2604    17118    counteragent counteragent_id    DEFAULT     �   ALTER TABLE ONLY public.counteragent ALTER COLUMN counteragent_id SET DEFAULT nextval('public.counteragent_counteragent_id_seq'::regclass);
 K   ALTER TABLE public.counteragent ALTER COLUMN counteragent_id DROP DEFAULT;
       public               postgres    false    231    232    232            m           2604    17103    details detail_id    DEFAULT     v   ALTER TABLE ONLY public.details ALTER COLUMN detail_id SET DEFAULT nextval('public.details_detail_id_seq'::regclass);
 @   ALTER TABLE public.details ALTER COLUMN detail_id DROP DEFAULT;
       public               postgres    false    228    230    230            n           2604    17104    details shelfid    DEFAULT     r   ALTER TABLE ONLY public.details ALTER COLUMN shelfid SET DEFAULT nextval('public.details_shelfid_seq'::regclass);
 >   ALTER TABLE public.details ALTER COLUMN shelfid DROP DEFAULT;
       public               postgres    false    229    230    230            t           2604    17158    employee employee_id    DEFAULT     |   ALTER TABLE ONLY public.employee ALTER COLUMN employee_id SET DEFAULT nextval('public.employee_employee_id_seq'::regclass);
 C   ALTER TABLE public.employee ALTER COLUMN employee_id DROP DEFAULT;
       public               postgres    false    239    240    240            p           2604    17128    invoice invoice_id    DEFAULT     x   ALTER TABLE ONLY public.invoice ALTER COLUMN invoice_id SET DEFAULT nextval('public.invoice_invoice_id_seq'::regclass);
 A   ALTER TABLE public.invoice ALTER COLUMN invoice_id DROP DEFAULT;
       public               postgres    false    233    235    235            q           2604    17129    invoice counteragentid    DEFAULT     �   ALTER TABLE ONLY public.invoice ALTER COLUMN counteragentid SET DEFAULT nextval('public.invoice_counteragentid_seq'::regclass);
 E   ALTER TABLE public.invoice ALTER COLUMN counteragentid DROP DEFAULT;
       public               postgres    false    235    234    235            r           2604    17142    invoice_detail invoiceid    DEFAULT     �   ALTER TABLE ONLY public.invoice_detail ALTER COLUMN invoiceid SET DEFAULT nextval('public.invoice_detail_invoiceid_seq'::regclass);
 G   ALTER TABLE public.invoice_detail ALTER COLUMN invoiceid DROP DEFAULT;
       public               postgres    false    238    236    238            s           2604    17143    invoice_detail detailid    DEFAULT     �   ALTER TABLE ONLY public.invoice_detail ALTER COLUMN detailid SET DEFAULT nextval('public.invoice_detail_detailid_seq'::regclass);
 F   ALTER TABLE public.invoice_detail ALTER COLUMN detailid DROP DEFAULT;
       public               postgres    false    237    238    238            u           2604    17167    invoice_employee invoiceid    DEFAULT     �   ALTER TABLE ONLY public.invoice_employee ALTER COLUMN invoiceid SET DEFAULT nextval('public.invoice_employee_invoiceid_seq'::regclass);
 I   ALTER TABLE public.invoice_employee ALTER COLUMN invoiceid DROP DEFAULT;
       public               postgres    false    241    244    244            v           2604    17168    invoice_employee responsible    DEFAULT     �   ALTER TABLE ONLY public.invoice_employee ALTER COLUMN responsible SET DEFAULT nextval('public.invoice_employee_responsible_seq'::regclass);
 K   ALTER TABLE public.invoice_employee ALTER COLUMN responsible DROP DEFAULT;
       public               postgres    false    242    244    244            w           2604    17169    invoice_employee granted_access    DEFAULT     �   ALTER TABLE ONLY public.invoice_employee ALTER COLUMN granted_access SET DEFAULT nextval('public.invoice_employee_granted_access_seq'::regclass);
 N   ALTER TABLE public.invoice_employee ALTER COLUMN granted_access DROP DEFAULT;
       public               postgres    false    244    243    244            x           2604    17189    invoice_log log_id    DEFAULT     x   ALTER TABLE ONLY public.invoice_log ALTER COLUMN log_id SET DEFAULT nextval('public.invoice_log_log_id_seq'::regclass);
 A   ALTER TABLE public.invoice_log ALTER COLUMN log_id DROP DEFAULT;
       public               postgres    false    245    246    246            i           2604    17075    rack rack_id    DEFAULT     l   ALTER TABLE ONLY public.rack ALTER COLUMN rack_id SET DEFAULT nextval('public.rack_rack_id_seq'::regclass);
 ;   ALTER TABLE public.rack ALTER COLUMN rack_id DROP DEFAULT;
       public               postgres    false    222    224    224            j           2604    17076    rack roomid    DEFAULT     j   ALTER TABLE ONLY public.rack ALTER COLUMN roomid SET DEFAULT nextval('public.rack_roomid_seq'::regclass);
 :   ALTER TABLE public.rack ALTER COLUMN roomid DROP DEFAULT;
       public               postgres    false    223    224    224            g           2604    17061    room room_id    DEFAULT     l   ALTER TABLE ONLY public.room ALTER COLUMN room_id SET DEFAULT nextval('public.room_room_id_seq'::regclass);
 ;   ALTER TABLE public.room ALTER COLUMN room_id DROP DEFAULT;
       public               postgres    false    219    221    221            h           2604    17062    room warehouseid    DEFAULT     t   ALTER TABLE ONLY public.room ALTER COLUMN warehouseid SET DEFAULT nextval('public.room_warehouseid_seq'::regclass);
 ?   ALTER TABLE public.room ALTER COLUMN warehouseid DROP DEFAULT;
       public               postgres    false    221    220    221            k           2604    17089    shelf shelf_id    DEFAULT     p   ALTER TABLE ONLY public.shelf ALTER COLUMN shelf_id SET DEFAULT nextval('public.shelf_shelf_id_seq'::regclass);
 =   ALTER TABLE public.shelf ALTER COLUMN shelf_id DROP DEFAULT;
       public               postgres    false    227    225    227            l           2604    17090    shelf rackid    DEFAULT     l   ALTER TABLE ONLY public.shelf ALTER COLUMN rackid SET DEFAULT nextval('public.shelf_rackid_seq'::regclass);
 ;   ALTER TABLE public.shelf ALTER COLUMN rackid DROP DEFAULT;
       public               postgres    false    227    226    227            f           2604    17051    warehouse warehouse_id    DEFAULT     �   ALTER TABLE ONLY public.warehouse ALTER COLUMN warehouse_id SET DEFAULT nextval('public.warehouse_warehouse_id_seq'::regclass);
 E   ALTER TABLE public.warehouse ALTER COLUMN warehouse_id DROP DEFAULT;
       public               postgres    false    217    218    218            ?          0    17115    counteragent 
   TABLE DATA           q   COPY public.counteragent (counteragent_id, counteragent_name, contact_person, phone_number, address) FROM stdin;
    public               postgres    false    232   *�       =          0    17100    details 
   TABLE DATA           J   COPY public.details (detail_id, shelfid, weight, type_detail) FROM stdin;
    public               postgres    false    230   u�       G          0    17155    employee 
   TABLE DATA           a   COPY public.employee (employee_id, employee_role, last_name, first_name, patronymic) FROM stdin;
    public               postgres    false    240   ��       B          0    17125    invoice 
   TABLE DATA           ^   COPY public.invoice (invoice_id, counteragentid, date_time, type_invoice, status) FROM stdin;
    public               postgres    false    235   ��       E          0    17139    invoice_detail 
   TABLE DATA           G   COPY public.invoice_detail (invoiceid, detailid, quantity) FROM stdin;
    public               postgres    false    238   �       K          0    17164    invoice_employee 
   TABLE DATA           `   COPY public.invoice_employee (invoiceid, responsible, granted_access, when_granted) FROM stdin;
    public               postgres    false    244   R�       M          0    17186    invoice_log 
   TABLE DATA           �   COPY public.invoice_log (log_id, invoice_id, old_status, new_status, old_date_time, new_date_time, changed_by, change_time) FROM stdin;
    public               postgres    false    246   ��       7          0    17072    rack 
   TABLE DATA           <   COPY public.rack (rack_id, roomid, rack_number) FROM stdin;
    public               postgres    false    224   %�       4          0    17058    room 
   TABLE DATA           A   COPY public.room (room_id, warehouseid, room_number) FROM stdin;
    public               postgres    false    221   ]�       :          0    17086    shelf 
   TABLE DATA           ?   COPY public.shelf (shelf_id, rackid, shelf_number) FROM stdin;
    public               postgres    false    227   ��       1          0    17048 	   warehouse 
   TABLE DATA           L   COPY public.warehouse (warehouse_id, warehouse_number, address) FROM stdin;
    public               postgres    false    218   ��       �           0    0     counteragent_counteragent_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.counteragent_counteragent_id_seq', 5, true);
          public               postgres    false    231            �           0    0    details_detail_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.details_detail_id_seq', 9, true);
          public               postgres    false    228            �           0    0    details_shelfid_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.details_shelfid_seq', 1, false);
          public               postgres    false    229            �           0    0    employee_employee_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.employee_employee_id_seq', 8, true);
          public               postgres    false    239            �           0    0    invoice_counteragentid_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.invoice_counteragentid_seq', 1, false);
          public               postgres    false    234            �           0    0    invoice_detail_detailid_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.invoice_detail_detailid_seq', 1, false);
          public               postgres    false    237            �           0    0    invoice_detail_invoiceid_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.invoice_detail_invoiceid_seq', 1, true);
          public               postgres    false    236            �           0    0 #   invoice_employee_granted_access_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.invoice_employee_granted_access_seq', 1, false);
          public               postgres    false    243            �           0    0    invoice_employee_invoiceid_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.invoice_employee_invoiceid_seq', 1, false);
          public               postgres    false    241            �           0    0     invoice_employee_responsible_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.invoice_employee_responsible_seq', 1, false);
          public               postgres    false    242            �           0    0    invoice_invoice_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.invoice_invoice_id_seq', 10, true);
          public               postgres    false    233            �           0    0    invoice_log_log_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.invoice_log_log_id_seq', 7, true);
          public               postgres    false    245            �           0    0    rack_rack_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.rack_rack_id_seq', 5, true);
          public               postgres    false    222            �           0    0    rack_roomid_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.rack_roomid_seq', 1, false);
          public               postgres    false    223            �           0    0    room_room_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.room_room_id_seq', 5, true);
          public               postgres    false    219            �           0    0    room_warehouseid_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.room_warehouseid_seq', 1, false);
          public               postgres    false    220            �           0    0    shelf_rackid_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.shelf_rackid_seq', 1, false);
          public               postgres    false    226            �           0    0    shelf_shelf_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.shelf_shelf_id_seq', 5, true);
          public               postgres    false    225            �           0    0    warehouse_warehouse_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.warehouse_warehouse_id_seq', 5, true);
          public               postgres    false    217            �           2606    17122    counteragent counteragent_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.counteragent
    ADD CONSTRAINT counteragent_pkey PRIMARY KEY (counteragent_id);
 H   ALTER TABLE ONLY public.counteragent DROP CONSTRAINT counteragent_pkey;
       public                 postgres    false    232            �           2606    17108    details details_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY public.details
    ADD CONSTRAINT details_pkey PRIMARY KEY (detail_id);
 >   ALTER TABLE ONLY public.details DROP CONSTRAINT details_pkey;
       public                 postgres    false    230            �           2606    17160    employee employee_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (employee_id);
 @   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_pkey;
       public                 postgres    false    240            �           2606    17194    invoice_log invoice_log_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.invoice_log
    ADD CONSTRAINT invoice_log_pkey PRIMARY KEY (log_id);
 F   ALTER TABLE ONLY public.invoice_log DROP CONSTRAINT invoice_log_pkey;
       public                 postgres    false    246            �           2606    17131    invoice invoice_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (invoice_id);
 >   ALTER TABLE ONLY public.invoice DROP CONSTRAINT invoice_pkey;
       public                 postgres    false    235                       2606    17078    rack rack_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_pkey PRIMARY KEY (rack_id);
 8   ALTER TABLE ONLY public.rack DROP CONSTRAINT rack_pkey;
       public                 postgres    false    224            }           2606    17064    room room_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (room_id);
 8   ALTER TABLE ONLY public.room DROP CONSTRAINT room_pkey;
       public                 postgres    false    221            �           2606    17092    shelf shelf_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.shelf
    ADD CONSTRAINT shelf_pkey PRIMARY KEY (shelf_id);
 :   ALTER TABLE ONLY public.shelf DROP CONSTRAINT shelf_pkey;
       public                 postgres    false    227            {           2606    17055    warehouse warehouse_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (warehouse_id);
 B   ALTER TABLE ONLY public.warehouse DROP CONSTRAINT warehouse_pkey;
       public                 postgres    false    218            �           2620    17214    shelf trg_add_default_detail    TRIGGER     ~   CREATE TRIGGER trg_add_default_detail AFTER INSERT ON public.shelf FOR EACH ROW EXECUTE FUNCTION public.add_default_detail();
 5   DROP TRIGGER trg_add_default_detail ON public.shelf;
       public               postgres    false    266    227            �           2620    17208    room trg_add_default_rack    TRIGGER     y   CREATE TRIGGER trg_add_default_rack AFTER INSERT ON public.room FOR EACH ROW EXECUTE FUNCTION public.add_default_rack();
 2   DROP TRIGGER trg_add_default_rack ON public.room;
       public               postgres    false    221    263            �           2620    17206    warehouse trg_add_default_room    TRIGGER     ~   CREATE TRIGGER trg_add_default_room AFTER INSERT ON public.warehouse FOR EACH ROW EXECUTE FUNCTION public.add_default_room();
 7   DROP TRIGGER trg_add_default_room ON public.warehouse;
       public               postgres    false    218    262            �           2620    17210    rack trg_add_default_shelf    TRIGGER     {   CREATE TRIGGER trg_add_default_shelf AFTER INSERT ON public.rack FOR EACH ROW EXECUTE FUNCTION public.add_default_shelf();
 3   DROP TRIGGER trg_add_default_shelf ON public.rack;
       public               postgres    false    248    224            �           2620    17212 !   warehouse trg_delete_related_data    TRIGGER     �   CREATE TRIGGER trg_delete_related_data BEFORE DELETE ON public.warehouse FOR EACH ROW EXECUTE FUNCTION public.delete_related_data();
 :   DROP TRIGGER trg_delete_related_data ON public.warehouse;
       public               postgres    false    265    218            �           2620    17204    invoice trg_fill_invoice_detail    TRIGGER     �   CREATE TRIGGER trg_fill_invoice_detail AFTER INSERT ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.fill_invoice_detail();
 8   DROP TRIGGER trg_fill_invoice_detail ON public.invoice;
       public               postgres    false    235    264            �           2620    17202 !   invoice trg_fill_invoice_employee    TRIGGER     �   CREATE TRIGGER trg_fill_invoice_employee AFTER INSERT ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.fill_invoice_employee();
 :   DROP TRIGGER trg_fill_invoice_employee ON public.invoice;
       public               postgres    false    261    235            �           2620    17200    invoice trg_log_invoice_changes    TRIGGER     �   CREATE TRIGGER trg_log_invoice_changes AFTER UPDATE ON public.invoice FOR EACH ROW EXECUTE FUNCTION public.log_invoice_changes();
 8   DROP TRIGGER trg_log_invoice_changes ON public.invoice;
       public               postgres    false    260    235            �           2620    17216 #   shelf trg_update_shelfid_in_details    TRIGGER     �   CREATE TRIGGER trg_update_shelfid_in_details AFTER UPDATE ON public.shelf FOR EACH ROW EXECUTE FUNCTION public.update_shelfid_in_details();
 <   DROP TRIGGER trg_update_shelfid_in_details ON public.shelf;
       public               postgres    false    227    247            �           2606    17109    details details_shelfid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.details
    ADD CONSTRAINT details_shelfid_fkey FOREIGN KEY (shelfid) REFERENCES public.shelf(shelf_id);
 F   ALTER TABLE ONLY public.details DROP CONSTRAINT details_shelfid_fkey;
       public               postgres    false    227    230    4737            �           2606    17132 #   invoice invoice_counteragentid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_counteragentid_fkey FOREIGN KEY (counteragentid) REFERENCES public.counteragent(counteragent_id);
 M   ALTER TABLE ONLY public.invoice DROP CONSTRAINT invoice_counteragentid_fkey;
       public               postgres    false    4741    232    235            �           2606    17149 +   invoice_detail invoice_detail_detailid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.invoice_detail
    ADD CONSTRAINT invoice_detail_detailid_fkey FOREIGN KEY (detailid) REFERENCES public.details(detail_id);
 U   ALTER TABLE ONLY public.invoice_detail DROP CONSTRAINT invoice_detail_detailid_fkey;
       public               postgres    false    238    230    4739            �           2606    17144 ,   invoice_detail invoice_detail_invoiceid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.invoice_detail
    ADD CONSTRAINT invoice_detail_invoiceid_fkey FOREIGN KEY (invoiceid) REFERENCES public.invoice(invoice_id);
 V   ALTER TABLE ONLY public.invoice_detail DROP CONSTRAINT invoice_detail_invoiceid_fkey;
       public               postgres    false    4743    238    235            �           2606    17180 5   invoice_employee invoice_employee_granted_access_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_granted_access_fkey FOREIGN KEY (granted_access) REFERENCES public.employee(employee_id);
 _   ALTER TABLE ONLY public.invoice_employee DROP CONSTRAINT invoice_employee_granted_access_fkey;
       public               postgres    false    4745    240    244            �           2606    17170 0   invoice_employee invoice_employee_invoiceid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_invoiceid_fkey FOREIGN KEY (invoiceid) REFERENCES public.invoice(invoice_id);
 Z   ALTER TABLE ONLY public.invoice_employee DROP CONSTRAINT invoice_employee_invoiceid_fkey;
       public               postgres    false    4743    235    244            �           2606    17175 2   invoice_employee invoice_employee_responsible_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.invoice_employee
    ADD CONSTRAINT invoice_employee_responsible_fkey FOREIGN KEY (responsible) REFERENCES public.employee(employee_id);
 \   ALTER TABLE ONLY public.invoice_employee DROP CONSTRAINT invoice_employee_responsible_fkey;
       public               postgres    false    240    244    4745            �           2606    17079    rack rack_roomid_fkey    FK CONSTRAINT     w   ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_roomid_fkey FOREIGN KEY (roomid) REFERENCES public.room(room_id);
 ?   ALTER TABLE ONLY public.rack DROP CONSTRAINT rack_roomid_fkey;
       public               postgres    false    221    224    4733            �           2606    17065    room room_warehouseid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_warehouseid_fkey FOREIGN KEY (warehouseid) REFERENCES public.warehouse(warehouse_id);
 D   ALTER TABLE ONLY public.room DROP CONSTRAINT room_warehouseid_fkey;
       public               postgres    false    218    4731    221            �           2606    17093    shelf shelf_rackid_fkey    FK CONSTRAINT     y   ALTER TABLE ONLY public.shelf
    ADD CONSTRAINT shelf_rackid_fkey FOREIGN KEY (rackid) REFERENCES public.rack(rack_id);
 A   ALTER TABLE ONLY public.shelf DROP CONSTRAINT shelf_rackid_fkey;
       public               postgres    false    227    224    4735            @           826    17246     DEFAULT PRIVILEGES FOR FUNCTIONS    DEFAULT ACL     g   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO warehouse_owner;
          public               postgres    false            ?           826    17245    DEFAULT PRIVILEGES FOR TABLES    DEFAULT ACL     g   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO warehouse_owner;
          public               postgres    false            ?   ;  x�U�]N�@��gV1�!��ۅ���"M4��L*�B)l��yf�Ŧ}��=�~���
��1-L�I�-�`��GX��;o)�#�]i�E�
;Q�==;�8Qr��m��KV҇L�`+=���RwGO<ꛚ�&HFM�]�̰A�N��U5+�`_2tU��AƁ�4pW:::Ky���\r�5�X`ͅX9l��aF�j&7߹;�v^��(�j;�m������]r�ɦ��){z<�>hg���`��F�ՙ�(�ɸ���ݣ�W�H�h�ܸ7�V�7��F�-�-d�_�𔥌�=�f��G�8�m����wm���	J      =   z   x��=
�P���Sx�ŷ/�\��D�X���e�>&��7r���&!!��ƙ�����կb0�0r��w������O�5�
�HF���7��9�I4h5���v�K	`*j�#΂&'��~Cf      G   �   x���M
1���)<���m<Lu��u%"H���qF=�ˍLc�X\��%���a�.x����jE���((Y�1� V�꾂�d�6�U�����wL��	a�<�/ˊ��6�&�����<�d��?˯�%���p�E��G�+8���Sp���s/���      B   U   x�Eͻ	�0E�Z�B8<��h�Ԟ���T.���`9�&�r@�;y��FEn[�E[�j��&'e[���M���{.f~n�      E   /   x�ű !�x����`��ׁ~�	!eӌ�E���q2毼�� ���      K   P   x�Eͻ�@�����v���_��'K�O��P\^�@�ݨ�%$G܈�#��	cv��G�����.b����KU_��      M   c   x�3�4�L�,�4202�50�50T0��20 "�b�e�y�e�pYCC+#C+3=SCKsSK.s��%$Z���441�Pc+cK=s#3s�=... ^r$"      7   (   x���  �7[�zvc�u�$Q�U�̨�U���i�"      4   %   x�3�4�4�2�B.cN �2�B.SN ����� K�2      :   )   x�3�4�440�2�B m�	�@ڄ��)'�=... ��      1   �   x�3�440��|a��)@z�}6]�p�_G����DG����.6 E�(8r���Ϻ����{L��-P48q5�4,J4"k�Z�������a��[�Rp'�hp�2j0�i�t���v$�&��(�]�b���� ��z`     