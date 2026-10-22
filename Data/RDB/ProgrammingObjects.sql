/*
select * from AppUser;
select * from Room;
select * from Reservation;
select * from RoomAvailability;
select * from Sensor;
select * from SensorLog;
execute procRecordEvent '00:1A:2B:3C:4D:01', 'Enter';
execute procCreateRoomAvailabilityBetweenDates '2026-10-19', '2026-10-22';

*/



if OBJECT_ID('procRecordEvent', 'P') is not null
    drop procedure procRecordEvent;

if OBJECT_ID('trgUpdateRoomStatus', 'TR') is not null
    drop trigger trgUpdateRoomStatus;

go
create or alter procedure procRecordEvent
    @MacAddress nvarchar(17),
    @EventType nvarchar(5)
as
BEGIN
    declare @SensorID int;
    select @SensorID = SensorID from Sensor where MacAddress = @MacAddress;

    insert into SensorLog (SensorID, EventType, EventDateTime) values (
        @SensorID,
        @EventType,
        SYSDATETIMEOFFSET() at time zone 'Eastern Standard Time'
    );


END


go

create or alter trigger trgUpdateRoomStatus
on SensorLog
after INSERT
AS
BEGIN

    declare @EventType NVARCHAR(10), @RoomID int
    select @EventType = i.EventType, @RoomID = s.RoomID
    from inserted i
    inner join Sensor s on i.sensorid = s.sensorid

    -- trigger action
    if (@EventType = 'Enter')
    begin
        execute procUpdateRoomStatus @RoomID, 'Occupied'
    end
    else if (@EventType = 'Exit')
    begin
        execute procUpdateRoomStatus @RoomID, 'Available'
    end


end

go

create or alter procedure procUpdateRoomStatus
    @RoomID int,
    @EventType NVARCHAR(10)
as
BEGIN
    update Room
    set CurrentStatus = @EventType
    where RoomID = @RoomID
end;


go

-- generate 15-minute RoomAvailability slots from 8 AM to 8 PM on a given date for every room
create or alter PROCEDURE procCreateRoomAvailabilityForOneDay
    @CurrentDate date
as
begin
-- generate 15-minute RoomAvailability slots from 8 AM to 8 PM on current date for every room
    declare @AvailableDate date = @CurrentDate;
    declare @SlotStart time;
    declare @RoomID int;
    declare @NumberOfRooms int, @Counter int;
    set @NumberOfRooms = (select count(*) from Room);
    set @RoomID = 1;
    set @Counter = 0;

    while @Counter < @NumberOfRooms -- loop through each room (1, 2, 3, 4 )
    begin
        set @SlotStart = '08:00:00';
        while @SlotStart < '20:00:00' -- loop through each 15-minute slot (8:00, 8:15, 8:30, ..., 19:45)
        begin
            insert into RoomAvailability (RoomID, AvailableDate, StartTime, EndTime, AvailabilityStatus)
            values (@RoomID, @AvailableDate, @SlotStart, dateadd(minute, 15, @SlotStart), 'Available');

            set @SlotStart = dateadd(minute, 15, @SlotStart);
        end
        set @RoomID = @RoomID + 1;
        set @Counter = @Counter + 1;
    end

end;
go

GO

-- Create room availability for the next 7 days
create or alter PROCEDURE procCreateRoomAvailabilityForNext7Days
AS
begin
    declare @numberOfDays int = 0;
    declare @currentDate date = getdate(); -- dateadd(day, 1, getdate()); -- start from tomorrow
    while @numberOfDays < 7
    begin
        execute procCreateRoomAvailabilityForOneDay @currentDate;
        set @numberOfDays = @numberOfDays + 1;
        set @currentDate = dateadd(day, 1, @currentDate);
    end
end
-- execute procCreateRoomAvailabilityForNext7Days;

GO
-- create room avail for between 2 dates


create or alter PROCEDURE procCreateRoomAvailabilityBetweenDates
    @StartDate date,
    @EndDate date
AS
begin
    declare @numberOfDays int, @counter int;
    set @numberOfDays = datediff(day, @StartDate, @EndDate) + 1; -- include end date
    declare @currentDate date; 
    set @currentDate = @StartDate;
    set @counter = 0; 
    while @counter < @numberOfDays
    begin
        execute procCreateRoomAvailabilityForOneDay @currentDate;
        set @counter = @counter + 1;
        set @currentDate = dateadd(day, 1, @currentDate);
    end
end

-- execute procCreateRoomAvailabilityBetweenDates '2026-10-19', '2026-10-22';



-- create reservation proceudre procCreateReservation

-- create update room availability trigger trgUpdateRoomAvailabilityOnReservation