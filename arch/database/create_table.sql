-- Dimension Table Hotel
CREATE TABLE Dim_Hotel (
    hotel_id INT PRIMARY KEY,
    hotel_type VARCHAR(255) NOT NULL
);

-- Dimension Table Arrival Time
CREATE TABLE Dim_Arrival_Time (
    arrival_date_id INT PRIMARY KEY,
    calendar_date DATE NOT NULL,
    year INT NOT NULL,
    month VARCHAR(255) NOT NULL,
    week_number INT NOT NULL,
    day_of_month INT NOT NULL
);

-- Dimension Table Costumer
CREATE TABLE Dim_Customer (
    customer_id INT PRIMARY KEY,
    country VARCHAR(255),
    market_segment VARCHAR(255),
    distribution_channel VARCHAR(255),
    customer_type VARCHAR(255)
);

-- Dimension Table with Reservation Service Information
CREATE TABLE Dim_Service (
    service_id INT PRIMARY KEY,
    meal VARCHAR(255),
    reserved_room_type VARCHAR(255),
    assigned_room_type VARCHAR(255),
    deposit_type VARCHAR(255)
);

-- Dimension Table Status of Reservation
CREATE TABLE Dim_Status (
    status_id INT PRIMARY KEY,
    reservation_status VARCHAR(255),
    reservation_status_date DATE
);

-- Fact Table
CREATE TABLE Fact_Booking (
    booking_id INT PRIMARY KEY,
    hotel_id INT,
    arrival_date_id INT,
    customer_id INT,
    service_id INT,
    status_id INT,
    is_canceled INT,
    lead_time INT,
    adults INT,
    children INT,
    babies INT,
    booking_changes INT,
    days_in_waiting_list INT,
    total_of_special_requests INT,
    required_car_parking_spaces INT,
    CONSTRAINT fk_hotel FOREIGN KEY (hotel_id) REFERENCES Dim_Hotel(hotel_id),
    CONSTRAINT fk_arrival_date FOREIGN KEY (arrival_date_id) REFERENCES Dim_Arrival_Time(arrival_date_id),
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES Dim_Customer(customer_id),
    CONSTRAINT fk_service FOREIGN KEY (service_id) REFERENCES Dim_Service(service_id),
    CONSTRAINT fk_status FOREIGN KEY (status_id) REFERENCES Dim_Status(status_id)
);

-- Indexes for improve performance of queries
CREATE INDEX idx_hotel_id ON Fact_Booking (hotel_id);
CREATE INDEX idx_arrival_date_id ON Fact_Booking (arrival_date_id);
CREATE INDEX idx_customer_id ON Fact_Booking (customer_id);
CREATE INDEX idx_service_id ON Fact_Booking (service_id);
CREATE INDEX idx_status_id ON Fact_Booking (status_id);
