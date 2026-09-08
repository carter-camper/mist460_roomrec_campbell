/*

-- in your master database

CREATE LOGIN NandaSurendra

WITH PASSWORD = 'MI$T460Instructor';

-- switch to your mist460-rdb-lastname database;

CREATE USER NandaSurendra

FOR LOGIN NandaSurendra;

ALTER ROLE db_owner ADD MEMBER NandaSurendra;

*/
drop table if exists RoomAvailability;  --tell nanda to flip these, parent child key problem
drop table if exists Room;
go

create table Room (
    RoomID int identity (1,1) primary key,
    RoomNumber varchar(10) not null,
    Whiteboard bit not null
);

GO
create table RoomAvailability (
    RoomAvailabilityID int identity (1,1) primary key,
    RoomID int not null,
    AvailableDate date not null,
    AvailableStartTime datetime not null,
    --AvailableEndTime datetime not null,    DIDNT INCLUDE START TIME IN VIDEO
    constraint FK_RoomAvailability_Room foreign key (RoomID) references Room(RoomID)
);