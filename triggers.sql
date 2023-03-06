------------------ ТРИГГЕР НА ИЗМЕНЕНИЕ ТАБЛИЦЫ employees ------------------
-- Основные кейсы:
   -- добавление нового сотрудника
      -- Проверить, есть ли вакантные места

	  	-- Основной сценарий: если есть, добавляем запись в employees, emps_history не обновляем 

	    -- Альтернативный сценарий: 
	       -- нет вакантных мест. 
	       -- Если Количество штатных единиц равно 1, заменяем одного сотрудника другим. В emps_history, вносим предыдущую employees запись  
		   -- Если Количество штатных единиц больше 1, показываем предупреждение 
   
   -- изменение записи сотрудника
      -- Основной сценарий (что можно поменять: зарплата, дата)
	  -- если меняем ид_департамента, проверяем наличие вакантных мест в новом департаменте


   -- удаление записи о сотруднике
      -- скопировать запись в emps_history

------------------------------ ДО ИЗМЕНЕНИЙ ---------------------------------
create or replace function on_employees_change() returns trigger as $$
declare vacancy_amount integer; -- вакантные должности
        amount         integer; -- количество штатных единиц
begin 
	-- проверяем, сколько штатных единиц вакантно
	vacancy_amount = get_vacancy_amount(new.post_department_id);
	select pd.amount into amount from post_department pd where pd.id_post_department = new.post_department_id;
	-- добавление нового сотрудника или изменение записи сотрудника
    if ( TG_OP = 'UPDATE' and (new.post_department_id <> old.post_department_id) ) then 
      if vacancy_amount > 0 then
	    return new;
	  elsif vacancy_amount = 0 then	   
	    if amount = 1 then  --  если штатная единица одна, и она занята, будем заменять одного другим
	      return new;
	    elsif amount > 1 then -- если штатных единиц несколько, и они все заняты, нужно выбирать вместо кого нанимаем нового
	      raise exception 'Необходимо уволить одного из сотрудников или увеличить количество штатных единиц';
	    end if;
	  elsif vacancy_amount < 0 then	    
	    raise exception 'Недостаточно штатных единиц';
	  end if;
	elsif TG_OP = 'INSERT' then 
	  if vacancy_amount > 0 then
	    return new;
	  elsif vacancy_amount = 0 then	   
	    if amount = 1 then  --  если штатная единица одна, и она занята, будем заменять одного другим
	      return new;
	    elsif amount > 1 then -- если штатных единиц несколько, и они все заняты, нужно выбирать вместо кого нанимаем нового
	      raise exception 'Необходимо уволить одного из сотрудников или увеличить количество штатных единиц';
	    end if;
	  elsif vacancy_amount < 0 then	    
	    raise exception 'Недостаточно штатных единиц';
	  end if;
	end if;
return null;
end;
$$ language plpgsql;

create trigger employees_change
before insert or update on employees 
for each row execute procedure on_employees_change();     


-- получить количество вакантных мест
create or replace function get_vacancy_amount(id_pd integer) returns integer as $$
declare 
  vacancy_amount integer;
  emps_amount    integer;
begin 
  select count(e.employee_id) into emps_amount from employees e where e.post_department_id = id_pd;
  if emps_amount is null then emps_amount = 0; end if;
  select pd.amount - emps_amount 
    into vacancy_amount
    from post_department pd
   where pd.id_post_department = id_pd;

  return vacancy_amount;
end;
$$ language plpgsql;


-- получаем предшествующую запись по должности и дате
create or replace function get_emp_id( new_date_from date, new_pd integer, new_emp_id integer ) returns int as $$
declare emp_id int;
begin
	   select e.employee_id  
	     into emp_id
	     from employees e
	    where e.post_department_id = $2
          and e.date_from < $1
          and e.employee_id <> $3;
  return emp_id;
end;
$$ language plpgsql;

------------------------------ ПОСЛЕ ИЗМЕНЕНИЙ ---------------------------------
create or replace function after_employees_change() returns trigger as $$
declare emp_id         int;
        vacancy_amount int;
        date_f   	  date;
        sal        numeric;
        pers_id    	   int;
        pd_id          int;
begin 
	-- проверяем, сколько штатных единиц вакантно
	vacancy_amount = get_vacancy_amount(new.post_department_id);
	-- добавление нового сотрудника, изменение записи сотрудника (новый департамент)
	if TG_OP = 'INSERT' or ( TG_OP = 'UPDATE' and (new.post_department_id <> old.post_department_id) ) then 
      -- до вставки или изменения была ровна одна вакансия, занятая другим сотрудником
      if vacancy_amount < 0 then
      -- старого сотрудника удаляем из employees и записываем в emps_history
	    emp_id = get_emp_id( new.date_from, new.post_department_id, new.employee_id );    	  
	    select e.employee_id, e.person_id, e.date_from, e.salary, e.post_department_id  
	      from employees e
         where e.employee_id = emp_id
          into emp_id, pers_id, date_f, sal, pd_id;			  	
        insert into emps_history ( date_from, date_to, salary, person_id, post_department_id, employee_id ) 
  	         values ( date_f, current_date, sal, pers_id, pd_id, emp_id ); 	   
	    delete from employees where employee_id = emp_id;
	  -- есть несколько штатных единиц на данную должность, ищеющегося сотрудника устраиваем на новую на свободную должность
	  -- запись о старой должности зиписываем в историю
	  elsif TG_OP = 'UPDATE' and vacancy_amount >= 0 then
	     insert into emps_history ( date_from, date_to, salary, person_id, post_department_id, employee_id ) 
  	     values ( old.date_from, current_date, old.salary, old.person_id, old.post_department_id, old.employee_id ); 
	  end if;
	-- изменение записи сотрудника не связано с изменением должности.
	-- удаляем из employees old, записываем ее в emps_history
	elsif TG_OP = 'UPDATE' then
       insert into emps_history ( date_from, date_to, salary, person_id, post_department_id, employee_id ) 
  	     values ( old.date_from, current_date, old.salary, old.person_id, old.post_department_id, old.employee_id ); 	 
	elsif TG_OP = 'DELETE' then
	  if ( old.employee_id not in ( select employee_id from emps_history ) ) then
       insert into emps_history ( date_from, date_to, salary, person_id, post_department_id, employee_id ) 
  	     values ( old.date_from, current_date, old.salary, old.person_id, old.post_department_id, old.employee_id ); 
	  end if;
	end if;
return null;
end;
$$ language plpgsql;

create trigger emps_history_change
after insert or update or delete on employees 
for each row execute procedure after_employees_change(); 


select * from get_vacancy_amount(8);
INSERT INTO public.employees (date_from,salary,person_id,post_department_id) VALUES
('2023-06-04',152000,7,7);
update employees set post_department_id = 8 where employee_id = 8;

select * from update_emps_history( 12 );
select * from insert_emps_history(12)  ; 