insert into Room (RoomNumber, Floor, Seats, Whiteboard) values
('REH 4213', 4, 4, 1),
('REH 4225', 4, 6, 0),
('REH 5213', 5, 4, 1),
('REH 5225', 5, 6, 0);

go

insert into Sensor (SensorName, TransmitterName, RoomID) values
('LD2410C', 'ESP32-S3-WROOM-1', 1),
('LD2410C', 'ESP32-S3-WROOM-1', 2),
('LD2410C', 'ESP32-S3-WROOM-1', 3),
('LD2410C', 'ESP32-S3-WROOM-1', 4);


go

insert into AppUser (FirstName, LastName, AppUserEmail, AppUserPassword, AppUserRole) values
('Alice', 'Smith', 'alice.smith@school.edu', 'hashed_password_1', 'Admin'),
('Bob', 'Johnson', 'bob.johnson@school.edu', 'hashed_password_2', 'User'),
('Charlie', 'Brown', 'charlie.brown@school.edu', 'hashed_password_3', 'User'),
('David', 'Williams', 'david.williams@school.edu', 'hashed_password_4', 'User');


go

-- generate 15-minute RoomAvailability slots from 8 AM to 8 PM on current date for every room
declare @AvailableDate date = getdate();
declare @SlotStart time;
declare @RoomID int;

declare room_cursor cursor for select RoomID from Room;
open room_cursor;
fetch next from room_cursor into @RoomID;

while @@FETCH_STATUS = 0
begin
    set @SlotStart = '08:00:00';
    while @SlotStart < '20:00:00'
    begin
        insert into RoomAvailability (RoomID, AvailableDate, StartTime, EndTime, AvailabilityStatus)
        values (@RoomID, @AvailableDate, @SlotStart, dateadd(minute, 15, @SlotStart), 'Available');

        set @SlotStart = dateadd(minute, 15, @SlotStart);
    end
    fetch next from room_cursor into @RoomID;
end

close room_cursor;
deallocate room_cursor;

go

select * from AppUser;
