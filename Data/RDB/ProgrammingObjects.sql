/*
select * from AppUser;
select * from Room;
select * from Reservation;
select * from RoomAvailability;
select * from Sensor;
select * from SensorLog;
execute procRecordEvent '00:1A:2B:3C:4D:01', 'Enter';
execute procCreateRoomAvailabilityBetweenDates '2026-10-19', '2026-10-22';
execute procCreateReservation 1, 1, '2026-10-28', '10:00', '11:00';

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


go

-- reserve a room for a block of consecutive 15-minute slots (max 2 hours)
create or alter procedure procCreateReservation
    @AppUserID int,
    @RoomID int,
    @ReservationDate date,
    @StartTime time,
    @EndTime time
as
begin
    set xact_abort on; -- any error rolls back the whole reservation

    declare @Minutes int = datediff(minute, @StartTime, @EndTime);
    declare @Now datetime2 = sysdatetimeoffset() at time zone 'Eastern Standard Time';

    if @Minutes not between 15 and 120
        throw 50001, 'Reservation must be between 15 minutes and 2 hours.', 1;

    if cast(@ReservationDate as datetime) + cast(@StartTime as datetime) < @Now
        throw 50003, 'Cannot reserve a time in the past.', 1;

    -- a user can't hold two active reservations that overlap (can't be in two rooms at once)
    if exists (
        select 1
        from Reservation r
        inner join RoomAvailability ra on r.ReservationID = ra.ReservationID
        where r.AppUserID = @AppUserID
          and r.ReservationStatus in ('Reserved', 'CheckedIn')
          and ra.AvailableDate = @ReservationDate
          and ra.StartTime < @EndTime
          and ra.EndTime > @StartTime
    )
        throw 50004, 'You already have a reservation during this time.', 1;

    begin transaction;

    insert into Reservation (AppUserID, ReservationDateTime, TotalTimeReserved) values (@AppUserID, @Now, @Minutes);
    declare @ReservationID int = scope_identity();

    -- claim only slots that are still open; the row locks keep two users from grabbing the same slot
    -- trgUpdateRoomAvailabilityOnReservation marks the claimed slots 'Reserved'
    update RoomAvailability
    set ReservationID = @ReservationID
    where RoomID = @RoomID
      and AvailableDate = @ReservationDate
      and StartTime >= @StartTime
      and EndTime <= @EndTime
      and AvailabilityStatus = 'Available';

    -- every slot in the range must have been claimed (catches taken slots, unaligned times, outside hours)
    if @@ROWCOUNT <> @Minutes / 15
    begin
        rollback transaction;
        throw 50002, 'One or more requested time slots are not available.', 1;
    end

    commit transaction;

    select @ReservationID as ReservationID;
end

go

-- keep AvailabilityStatus in sync with ReservationID: linked slot = 'Reserved', unlinked slot = 'Available'
-- a manual edit to AvailabilityStatus is overwritten, so the two columns can never disagree
create or alter trigger trgUpdateRoomAvailabilityOnReservation
on RoomAvailability
after update
as
begin
    if not (update(ReservationID) or update(AvailabilityStatus)) return;

    update ra
    set AvailabilityStatus = case when i.ReservationID is null then 'Available' else 'Reserved' end
    from RoomAvailability ra
    inner join inserted i on ra.RoomAvailabilityID = i.RoomAvailabilityID;
end

go

-- cancel a user's upcoming reservation and free its slots; the reservation row is kept for history
create or alter procedure procCancelReservation
    @ReservationID int,
    @AppUserID int
as
begin
    set xact_abort on;

    begin transaction;

    -- only the owner can cancel, and only before check-in
    update Reservation
    set ReservationStatus = 'Cancelled'
    where ReservationID = @ReservationID
      and AppUserID = @AppUserID
      and ReservationStatus = 'Reserved';

    if @@ROWCOUNT = 0
    begin
        rollback transaction;
        throw 50005, 'Reservation not found or can no longer be cancelled.', 1;
    end

    -- trgUpdateRoomAvailabilityOnReservation marks the freed slots 'Available'
    update RoomAvailability
    set ReservationID = null
    where ReservationID = @ReservationID;

    commit transaction;
end

/*
-- 1. make the reservation (10:00–11:00 = 4 slots)
execute procCreateReservation 2, 1, '2026-10-28', '10:00', '11:00';

-- 2. the new reservation (TotalTimeReserved should be 60, status 'Reserved')
select * from Reservation;

-- 3. the claimed slots: 10:00, 10:15, 10:30, 10:45 should have the ReservationID and 'Reserved'
select * from RoomAvailability
where RoomID = 1 and AvailableDate = '2026-10-28' and StartTime between '09:45' and '11:00'
order by StartTime;

execute procCreateRoomAvailabilityBetweenDates '2026-10-27', '2026-10-30';

execute procCreateReservation 2, 1, '2026-10-20', '10:00', '11:00'; -- past: error 50003
execute procCreateReservation 2, 1, '2026-10-28', '10:00', '11:00'; -- succeeds
execute procCreateReservation 2, 2, '2026-10-28', '10:30', '11:30'; -- same user, other room, overlaps: error 50004
update RoomAvailability set AvailabilityStatus = 'Available' where ReservationID is not null; -- the trigger sets it back to 'Reserved'


execute procCreateReservation 2, 1, '2026-10-28', '13:00', '14:00'; -- note the ReservationID it returns
execute procCancelReservation 4, 3; -- wrong user: error 50005
execute procCancelReservation 4, 2; -- succeeds
execute procCancelReservation 4, 2; -- already cancelled: error 50005

select * from Reservation where ReservationID = 4; -- status 'Cancelled'
select * from RoomAvailability where RoomID = 1 and AvailableDate = '2026-10-28' and StartTime between '13:00' and '13:45'; -- 'Available', ReservationID null


*/


