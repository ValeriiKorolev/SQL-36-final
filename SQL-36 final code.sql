SET search_path TO bookings;

-- ������� 1
-- � ����� ������� ������ ������ ���������?
-- ��� ���������� �� ������� � ������� airports
-- 

select city, count(airport_code) as airport_count
from airports 
group by city 
having count(airport_code) > 1
order by airport_count desc

-- ������� 2
-- � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������?
-- � ���������� �� ������� aircrafts ���������� ������� � ������������ ����������
-- � ������� flights, ��������� ������ ���������� � ��������� where, �������� ����� ����� ��������
-- ���������� � �������� ��������� � ������ ����������� �� ������� airports


select distinct a2.airport_code, a2.airport_name, a2.city 
from flights f 
inner join airports a2 on f.departure_airport = a2.airport_code 
where f.aircraft_code = (
	select a.aircraft_code
	from aircrafts a
	order by "range" desc
	limit 1)
 

-- ������� 3
-- ������� 10 ������ � ������������ �������� �������� ������
-- ���������� �� ������� � ������� flights. ��� ������� �������� ������ ��������� ��������� �������� ���� actual_departure.

select a.airport_name as "�������� ������", a.city as "�����", f.flight_no as "����� �����", 
	f.scheduled_departure as "����� ������ �� ����������", (f.actual_departure - f.scheduled_departure) as "�������� ������"
from flights f 
inner join airports a on f.departure_airport = a.airport_code 
where f.actual_departure is not null 
order by "�������� ������" desc
limit 10

-- ������� 4
-- ���� �� �����, �� ������� �� ���� �������� ���������� ������?
-- ��������
-- �������� � ��������� ticket_flights, boarding_passes � tickets.ticket_no 
-- ���������� ��� ����������. ������ ��������� ��������� ������ ������, � ������� ���� �� ������������ ��������, �.�. �� ������ ���������� ������, 
-- � ���������� �� �������� �������. ����� ���������� ������, � ������� ���� �� ���������� ���������� ������ 137640.
-- ������ ������ ������ ������ ���� ������ � ���������� ��������� �� ���. ������ ��������� ���������� ������������� ��� ����, ����� ��������� ����������
-- ��������� �� �������������� ������ (91381) � ������, � ������� ���� �� �������������� �������� (46259). 


select q1.book_ref as "����� �����", q2.book_tickets as "���-�� ��������� �� �����", q1.book_tickets_null as "���-�� �� ������������ ���������"
from (
select t.book_ref, count(tf.flight_id) as book_tickets_null -- ������ ����� � ���������� �� �������������� �� ����� ������ 
from ticket_flights tf 
left join boarding_passes bp on tf.ticket_no = bp.ticket_no and tf.flight_id = bp.flight_id   
left join tickets t on tf.ticket_no = t.ticket_no 
where bp.boarding_no is null
group by t.book_ref) q1
inner join (
select t.book_ref, count(tf.flight_id) as book_tickets -- ������ ����� � ������c��� ������ � �����
from ticket_flights tf 
left join tickets t on tf.ticket_no = t.ticket_no
group by t.book_ref) q2 on q1.book_ref = q2.book_ref
--where q2.book_tickets > q1.book_tickets_null -- ������� ����������� �������� ������������� ������
--where q2.book_tickets = q1.book_tickets_null -- ������� ����������� ��������� �� ������������� ������


-- ���� ������ ���������� �� ������ �������, �� - ����. �� ���������� ������ ������

select t.book_ref     -- ������ �� �������������� ������
from ticket_flights tf 
left join boarding_passes bp on tf.ticket_no = bp.ticket_no and tf.flight_id = bp.flight_id  
left join tickets t on tf.ticket_no = t.ticket_no 
where bp.boarding_no is null



-- ������� 5
-- ������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
-- �������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����. 
-- �.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� ��� �������� �� ������� ��������� �� ���� ��� ����� ������ ������ � ������� ���.
-- ��������
-- ������� ������� ��� ������������ ������� - flights. ��� ��������� ���������� ���������� ������ ���������� ���������� cte flight_filling, ��� ��� �������
-- ����� flight_id ������� ���������� ���������� �������.
-- ��� ��������� ���������� ���� � �������� - cte aircraft_seats
-- ��� ������� ���������� ������������ �� ���� ���������� �� ������� ��������� ����������� ������ ����� ������� ������� sum() � ������������ ������ order by.

with flight_filling as ( 
	select bp.flight_id, count(bp.boarding_no) as count_passenges 
	from boarding_passes bp 
	group by bp.flight_id
	), 
	aircraft_seats as (
	select s.aircraft_code, count(s.seat_no) as count_seats 
	from seats s 
	group by s.aircraft_code 
	) 
select a.airport_name as "��������", date(f.actual_departure) as "����", f.flight_no as "����� �����", 
		ff.count_passenges as "���-�� ����������", (acs.count_seats - ff.count_passenges) as "���-�� ��������� ����",
		round((acs.count_seats - ff.count_passenges)*100/acs.count_seats::numeric,1) as "% ��������� ����",  
		sum(ff.count_passenges) over (partition by departure_airport, date(actual_departure) order by actual_departure) as "���-�� �������. ���������� �� ����"
from flights f 
inner join flight_filling ff on f.flight_id = ff.flight_id
inner join aircraft_seats acs on f.aircraft_code = acs.aircraft_code
inner join airports a on f.departure_airport = a.airport_code 
order by departure_airport, actual_departure


-- ������� 6
-- ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������.
-- ��������
-- ������� ��� ������������ ������� - flights. ��������� ���������, ����������� ���������� ��������� ��� ������ ����� ��������.
-- ���������� ���������� ������� count() � ����������� �� ���� aircraft_code.
-- � �������� ������� ���������� ������� ������� sum() ��� ���������� ������ ���������� ���������.
-- ������ �������� �� ������� aircrafts 


select a.model as "������ ��������", round(100* q1.cf / sum(q1.cf) over(), 3) as "% ���������"
from
(select f.aircraft_code, count(f.flight_id) as cf
from flights f	
group by f.aircraft_code) q1
inner join aircrafts a on q1.aircraft_code = a.aircraft_code 
order by "% ���������" desc 
		

-- ������� 7
-- ���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������?
-- ��������
-- ���������� � � ������� ���� � ������� ticket_flights. ��� ��������� ��� ������� ������ � ������ ���������� ��� �������������:
-- ������� ��������� � ��������� ������-������, ������� ��������� � ��������� ������-������
-- ��������� ������� �� �������: ��������� ������ ������ ��������� ������.
-- ��������� � ����� �������� �� �������   

with tab_eco as (
	select distinct tf.flight_id, tf.amount 
	from ticket_flights tf 
	where tf.fare_conditions = 'Economy'
), tab_bus as (
	select distinct tf.flight_id, tf.amount 
	from ticket_flights tf 
	where tf.fare_conditions = 'Business')
select  tab_eco.flight_id, tab_eco.amount, tab_bus.amount
from tab_eco
left join tab_bus on tab_eco.flight_id = tab_bus.flight_id
where tab_eco.amount > tab_bus.amount


-- ������� 8
-- ����� ������ �������� ��� ������ ������?
-- ��������
-- ���������� ������� ���� ��������� ��� �������, ������� ���������, (��������� ������������) �� ������� airports. 
-- ��� ��� � ��������� ������� ���� ��������� ����������, ������ ���������� ���� � ������� distinct.
-- � ������� flights ���������� � ������� ����� ��������, �.�. ������ �����. 
-- ���������� ���� �������, ��������� ������ �������������� � ������������� city_direct_flight.
-- � ������� ��������� except ������ �������� ������, �.�. ���� �������, �� ������� ������ ����������
-- ���������: ������� 1 - 10100 ��������, ������� 2 - 516 ��������, ���� 9584 ���� ������� ��� ������ ������ 	
	

create view city_direct_flight as 	
	select distinct a.city as city_departure, a1.city as city_arrival
	from flights f 
	inner join airports a on f.departure_airport = a.airport_code  
	inner join airports a1 on f.arrival_airport = a1.airport_code; 

select *	
from (
	select distinct a1.city as city_departure, a2.city as city_arrival
	from airports a1 
	left join airports a2 on a1.city <> a2.city) q1 
except select city_departure, city_arrival
from city_direct_flight


-- ������� 9
-- ��������� ���������� ����� �����������, ���������� ������� �������, �������� � ���������� ������������ ���������� ���������  � ���������, ������������� ��� �����
-- ��������
-- �� ������� flights ��������� ���������� ������ ���������. �� ������� airports ����������� ���������� � ����������� ���������� �
-- ��������� ���������� �� ����������� �������. �� ������� aircrafts ����������� ������ �� ����� �������� � ���������.
-- ���������� ������������ ��������� �������� � ����������� ����� �����������, ��������� �������� �������.


select q1."�������� ������", q1."�������� �������", q1.distance as "����������", a2.model as "������ ��������", a2."range" as "����. ��������� ������", 
	case 
		when a2."range" > q1.distance then '�������'
		else '�� �������'
	end	as "��������"
from (
	select distinct a.airport_name as "�������� ������", a1.airport_name as "�������� �������", 
		round(6371 * acos(sind(a.latitude) * sind(a1.latitude) + cosd(a.latitude) * cosd(a1.latitude) * cosd(a.longitude - a1.longitude))::numeric) as distance, f.aircraft_code
	from flights f 
	inner join airports a on f.departure_airport = a.airport_code  
	inner join airports a1 on f.arrival_airport = a1.airport_code) q1
inner join aircrafts a2 on q1.aircraft_code = a2.aircraft_code
