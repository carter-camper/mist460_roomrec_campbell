insert into Room (RoomNumber, Floor, Seats, Whiteboard) values
('REH 4213', 4, 4, 1),
('REH 4225', 4, 6, 0),
('REH 5213', 5, 4, 1),
('REH 5225', 5, 6, 0);

go

insert into Sensor (MacAddress, SensorName, TransmitterName, RoomID) values
('00:1A:2B:3C:4D:01', 'LD2410C', 'ESP32-S3-WROOM-1', 1),
('00:1A:2B:3C:4D:02', 'LD2410C', 'ESP32-S3-WROOM-1', 2),
('00:1A:2B:3C:4D:03', 'LD2410C', 'ESP32-S3-WROOM-1', 3),
('00:1A:2B:3C:4D:04', 'LD2410C', 'ESP32-S3-WROOM-1', 4);



go


insert into AppUser (FirstName, LastName, AppUserEmail, AppUserPassword, AppUserRole) values
('Alice', 'Smith', 'alice.smith@school.edu', 'hashed_password_1', 'Admin'),
('Bob', 'Johnson', 'bob.johnson@school.edu', 'hashed_password_2', 'User'),
('Charlie', 'Brown', 'charlie.brown@school.edu', 'hashed_password_3', 'User'),
('David', 'Williams', 'david.williams@school.edu', 'hashed_password_4', 'User');


go




/*
declare @currentDate date = getdate();
print @currentDate;
execute procCreateRoomAvailabilityForOneDay @currentDate;
select * from RoomAvailability;
*/
