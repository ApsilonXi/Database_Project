CREATE TABLE warehouse 
(
	warehouse_id serial PRIMARY KEY,
	warehouse_number integer NOT NULL,
	address text NOT NUll
);

CREATE TABLE room
(
	room_id serial PRIMARY KEY,
	warehouseID serial NOT NULL,
	room_number integer NOT NULL,
	FOREIGN KEY (warehouseID) REFERENCES warehouse (warehouse_id)
);

CREATE TABLE rack
(
	rack_id serial PRIMARY KEY,
	roomID serial NOT NULL,
	rack_number integer NOT NULL,
	FOREIGN KEY (roomID) REFERENCES room (room_id)
);

CREATE TABLE shelf
(
	shelf_id serial PRIMARY KEY,
	rackID serial NOT NULL,
	shelf_number integer NOT NULL,
	FOREIGN KEY (rackID) REFERENCES rack (rack_id)
);

CREATE TABLE details
(
	detail_id serial PRIMARY KEY,
	shelfID serial NOT NULL,
	weight float NOT NULL,
	type_detail text NOT NULL,
	FOREIGN KEY (shelfID) REFERENCES shelf (shelf_id)
);

CREATE TABLE counteragent 
(
    counteragent_id serial PRIMARY KEY,
    counteragent_name varchar(128) NOT NULL,
    contact_person varchar(128) NOT NULL,
    phone_number bigint NOT NULL,  -- изменено с integer на bigint
    address text NOT NULL
);


CREATE TABLE invoice 
(
	invoice_id serial PRIMARY KEY,
	counteragentID serial NOT NULL,
	date_time timestamp NOT NULL,
	type_invoice bool NOT NULL,
	status bool NOT NULL,
	FOREIGN KEY (counteragentID) REFERENCES counteragent (counteragent_id)
);

CREATE TABLE invoice_detail 
(
	invoiceID serial NOT NULL,
	detailID serial NOT NULL,
	quantity integer NOT NULL,
	FOREIGN KEY (invoiceID) REFERENCES invoice (invoice_id),
	FOREIGN KEY (detailID) REFERENCES details (detail_id)
);

CREATE TABLE employee
(
	employee_id serial PRIMARY KEY,
	employee_role varchar(25) NOT NULL,
	last_name varchar(35) NOT NULL,
	first_name varchar(35) NOT NULL,
	patronymic varchar(35) NOT NULL
);

CREATE TABLE invoice_employee
(
	invoiceID serial NOT NULL,
	responsible serial NOT NULL,
	granted_access serial NOT NULL,
	when_granted timestamp NOT NULL,
	FOREIGN KEY (invoiceID) REFERENCES invoice (invoice_id),
	FOREIGN KEY (responsible) REFERENCES employee (employee_id),
	FOREIGN KEY (granted_access) REFERENCES employee (employee_id)
);

CREATE TABLE invoice_log (
    log_id serial PRIMARY KEY,
    invoice_id integer,
    old_status boolean,
    new_status boolean,
    old_date_time timestamp,
    new_date_time timestamp,
    changed_by text,
    change_time timestamp DEFAULT now()
);


CREATE TABLE stock (
    detail_id serial PRIMARY KEY,
    stock_quantity integer NOT NULL DEFAULT 0,
    last_updated timestamp DEFAULT now()
);

CREATE VIEW invoice_details_view AS
SELECT 
    inv.invoice_id,
    inv.counteragentID,
    inv.date_time,
    inv.type_invoice,
    inv.status,
    invd.detailID,
    invd.quantity,
    emp.last_name AS responsible_last_name,
    emp.first_name AS responsible_last_name,
    emp.patronymic AS responsible_patronymic
FROM
    invoice inv
JOIN
    invoice_detail invd ON inv.invoice_id = invd.invoiceID
JOIN
    details det ON invd.detailID = det.detail_id
JOIN
    invoice_employee inv_emp ON inv.invoice_id = inv_emp.invoiceID
JOIN
    employee emp ON inv_emp.responsible = emp.employee_id;
