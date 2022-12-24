SET search_path TO bookings;

-- Задание 1
-- В каких городах больше одного аэропорта?
-- Вся информация по запросу в таблице airports
-- 

select city, count(airport_code) as airport_count
from airports 
group by city 
having count(airport_code) > 1
order by airport_count desc

-- Задание 2
-- В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
-- В подзапросе из таблицы aircrafts определяем самолет с максимальной дальностью
-- В таблице flights, используя данные подзапроса в операторе where, отбираем рейсы этого самолета
-- Информацию о названии аэропорта и города подтягиваем из таблицы airports


select distinct a2.airport_code, a2.airport_name, a2.city 
from flights f 
inner join airports a2 on f.departure_airport = a2.airport_code 
where f.aircraft_code = (
	select a.aircraft_code
	from aircrafts a
	order by "range" desc
	limit 1)
 

-- Задание 3
-- Вывести 10 рейсов с максимальным временем задержки вылета
-- Информация по запросу в таблице flights. При расчете задержки вылета учитываем ненулевые значения поля actual_departure.

select a.airport_name as "Аэропорт вылета", a.city as "Город", f.flight_no as "Номер рейса", 
	f.scheduled_departure as "Время вылета по расписанию", (f.actual_departure - f.scheduled_departure) as "Задержка вылета"
from flights f 
inner join airports a on f.departure_airport = a.airport_code 
where f.actual_departure is not null 
order by "Задержка вылета" desc
limit 10

-- Задание 4
-- Были ли брони, по которым не были получены посадочные талоны?
-- Алгоритм
-- Работаем с таблицами ticket_flights, boarding_passes и tickets.ticket_no 
-- Сформируем два подзапроса. Первый подзапрос формирует список броней, в которых есть не состоявшиеся перелеты, т.е. не выданы посадочные талоны, 
-- и количество не выданных талонов. Общее количество броней, в которых есть не полученные посадочные талоны 137640.
-- Второй запрос выдает список всех броней и количество перелетов по ним. Второй подзапрос используем исключительно для того, чтобы вычислить количество
-- полностью не мспользованных броней (91381) и броней, в которых есть не использованные перелеты (46259). 


select q1.book_ref as "Номер брони", q2.book_tickets as "Кол-во перелетов по брони", q1.book_tickets_null as "Кол-во не состоявшихся перелетов"
from (
select t.book_ref, count(tf.flight_id) as book_tickets_null -- номера брони и количество не использованных по брони рейсов 
from ticket_flights tf 
left join boarding_passes bp on tf.ticket_no = bp.ticket_no and tf.flight_id = bp.flight_id   
left join tickets t on tf.ticket_no = t.ticket_no 
where bp.boarding_no is null
group by t.book_ref) q1
inner join (
select t.book_ref, count(tf.flight_id) as book_tickets -- номера брони и количеcтво рейсов в брони
from ticket_flights tf 
left join tickets t on tf.ticket_no = t.ticket_no
group by t.book_ref) q2 on q1.book_ref = q2.book_ref
--where q2.book_tickets > q1.book_tickets_null -- условие определения частично использованых броней
--where q2.book_tickets = q1.book_tickets_null -- условие определения полностью не использованых броней


-- Если просто ответитить на вопрос задания, Да - были. Не уникальный список броней

select t.book_ref     -- номера не использованных броней
from ticket_flights tf 
left join boarding_passes bp on tf.ticket_no = bp.ticket_no and tf.flight_id = bp.flight_id  
left join tickets t on tf.ticket_no = t.ticket_no 
where bp.boarding_no is null



-- Задание 5
-- Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
-- Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
-- Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.
-- Алгоритм
-- Базовая таблица для формирования запроса - flights. Для получения количества вылетевших рейсом пассажиров сформируем cte flight_filling, где для каждого
-- рейса flight_id считаем количество посадочных талонов.
-- Для получения количества мест в самолете - cte aircraft_seats
-- Для расчета количества отправленных за день пассажиров из каждого аэропорта нарастающим итогом берем оконную функцию sum() с обязательной опцией order by.

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
select a.airport_name as "Аэропорт", date(f.actual_departure) as "Дата", f.flight_no as "Номер рейса", 
		ff.count_passenges as "Кол-во пассажиров", (acs.count_seats - ff.count_passenges) as "Кол-во свободных мест",
		round((acs.count_seats - ff.count_passenges)*100/acs.count_seats::numeric,1) as "% свободных мест",  
		sum(ff.count_passenges) over (partition by departure_airport, date(actual_departure) order by actual_departure) as "Кол-во отправл. пассажиров за день"
from flights f 
inner join flight_filling ff on f.flight_id = ff.flight_id
inner join aircraft_seats acs on f.aircraft_code = acs.aircraft_code
inner join airports a on f.departure_airport = a.airport_code 
order by departure_airport, actual_departure


-- Задание 6
-- Найдите процентное соотношение перелетов по типам самолетов от общего количества.
-- Алгоритм
-- Таблица для формирования запроса - flights. Формируем подзапрос, формирующий количество перелетов для каждой марки самолета.
-- Используем аргегатную функцию count() и группировку по полю aircraft_code.
-- В основном запросе используем оконную функцию sum() для нахождения общего количества перелетов.
-- Модель самолета из таблицы aircrafts 


select a.model as "Модель самолета", round(100* q1.cf / sum(q1.cf) over(), 3) as "% перелетов"
from
(select f.aircraft_code, count(f.flight_id) as cf
from flights f	
group by f.aircraft_code) q1
inner join aircrafts a on q1.aircraft_code = a.aircraft_code 
order by "% перелетов" desc 
		

-- Задание 7
-- Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
-- Алгоритм
-- Информация о и классах мест в таблице ticket_flights. Для сравнения цен билетов бизнес и эконом сформируем два представления:
-- таблица перелетов и стоимости эконом-класса, таблица перелетов и стоимости бизнес-класса
-- Объединим таблицы по условию: стоимость Эконом больше стоимости Бизнес.
-- Перелетов с таким условием не найлено   

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


-- Задание 8
-- Между какими городами нет прямых рейсов?
-- Алгоритм
-- Сформируем таблицу всех возможных пар городов, имеющих аэропорты, (декартово произведение) из таблицы airports. 
-- Так как в некоторых городах есть несколько аэропортов, осавим уникальные пары с помощью distinct.
-- В таблице flights информация о полетах между городами, т.е. прямые рейсы. 
-- Сформируем пары городов, связанных прямым авиасообщением в представлении city_direct_flight.
-- С помощью оператора except найдем разность таблиц, т.е. пары городов, не имеющих прямых авиарейсов
-- Результат: Таблица 1 - 10100 значений, Таблица 2 - 516 значений, Итог 9584 пары городов без прямых рейсов 	
	

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


-- Задание 9
-- Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы
-- Алгоритм
-- Из таблицы flights формируем уникальный список перелетов. Из таблицы airports подтягиваем информацию о координатах аэропортов и
-- вычисляем расстояние по приведенной формуле. Из таблицы aircrafts подтягиваем данные по марке самолета и дальности.
-- Сравниваем максимальную дальность перелета с расстоянием между аэропортами, результат проверки выводим.


select q1."Аэропорт вылета", q1."Аэропорт прилета", q1.distance as "Расстояние", a2.model as "Модель самолета", a2."range" as "Макс. дальность полета", 
	case 
		when a2."range" > q1.distance then 'Долетит'
		else 'Не долетит'
	end	as "Проверка"
from (
	select distinct a.airport_name as "Аэропорт вылета", a1.airport_name as "Аэропорт прилета", 
		round(6371 * acos(sind(a.latitude) * sind(a1.latitude) + cosd(a.latitude) * cosd(a1.latitude) * cosd(a.longitude - a1.longitude))::numeric) as distance, f.aircraft_code
	from flights f 
	inner join airports a on f.departure_airport = a.airport_code  
	inner join airports a1 on f.arrival_airport = a1.airport_code) q1
inner join aircrafts a2 on q1.aircraft_code = a2.aircraft_code
