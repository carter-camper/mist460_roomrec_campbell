
select * from AppUser;
select * from Room;
select * from Reservation;
select * from RoomAvailability;
select * from Sensor;
select * from SensorLog;




if OBJECT_ID('procRecordEvent', 'P') is not null
    drop procedure procRecordEvent;

if OBJECT_ID('trgUpdateRoomStatus', 'TR') is not null
    drop trigger trgUpdateRoomStatus;

go
create or alter procedure procRecordEvent
    @SensorID int,
    @EventType nvarchar(5)
as
BEGIN

    insert into SensorLog (SensorID, EventType, EventDateTime) values (
        @SensorID,
        @EventType,
        GETDATE() at time zone 'Eastern Standard Time'
    )


END

-- execute procRecordEvent 1, 'Enter';
-- select * from SensorLog;
-- select * from sensor;
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
    update Room 
    set CurrentStatus = 'Occupied'
    where RoomID = @RoomID
    end


     if (@EventType = 'Exit')
    begin
    update Room 
    set CurrentStatus = 'Available'
    where RoomID = @RoomID
    end


end


-- execute procRecordEvent 1, 'Exit';
-- select * from SensorLog;
-- select * from sensor;
-- select * from Room;