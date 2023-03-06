--  получить иерархию департаментов
with recursive r as (
	select department_id, department_name, parent_id, 1 as level  
	  from departments
	 where department_id = 1
	 
	 union all 
	 
	 select departments.department_id, departments.department_name, departments.parent_id, r.level + 1 as level   
	   from departments
	   join r on departments.parent_id = r.department_id
)
select r.department_name as "Департамент", r.level as "Уровень в иерархии" from r;

-- узнать, в каких городах находятся департаменты
select distinct c.city_name
  from departments d,
       addresses a,
       cities c 
 where d.address_id = a.address_id 
   and a.city_id = c.city_id; 

-- узнать, кто руководители департаментов
select structure_info."Департамент",
	   structure_info."Должность руководителя",
	   p2.surname ||' '|| p2."name" as "Имя руководителя"
  from (
   		 select pd.id_post_department, d.department_name as "Департамент", p.post_name as "Должность руководителя" 
   		   from post_department pd 
   		   join posts p on pd.post_id = p.post_id 
		   join departments d on d.department_id = pd.department_id 	
  		  where pd.is_supervisor = 1
  ) as structure_info 
  left join employees e on e.post_department_id = structure_info.id_post_department
  left join persons p2 on p2.person_id = e.person_id; 

-- узнать, какова самая большая зарплата в каждом департаменте
 select d.department_name as "Департамент", max(e.salary) as "Максимальная зарплата"
   from employees e,
        post_department pd,
        departments d 
  where e.post_department_id = pd.id_post_department 
    and d.department_id = pd.department_id  
  group by d.department_name; 

-- получить иерархию должностей  
with recursive r as (
	select post_id, post_name , parent_id, 1 as level  
	  from posts
	 where post_id = 1
	 
	 union all 
	 
	 select posts.post_id, posts.post_name , posts.parent_id, r.level + 1 as level   
	   from posts
	   join r on posts.parent_id = r.post_id
)
select r.post_name as "Название должности", r.level as "Уровень в иерархии" from r;

-- получить список сотрудников с руководителями
select d.department_name as "Департамент",
       p2.surname ||' '|| p2."name" as "Сотрудник",
       p.post_name as "Должность",
       p1.post_name as "Должность руководителя",
       (
         select p3.surname ||' '|| p3."name"
           from post_department pd1,
                employees e1,
                persons p3
          where pd1.post_id = p1.post_id 
            and e1.post_department_id = pd1.id_post_department 
            and e1.person_id = p3.person_id 
       ) as "Имя руководителя"
  from employees e,
       post_department pd,
       departments d,
       posts p,
       posts p1,
       persons p2 
 where e.post_department_id = pd.id_post_department 
   and e.person_id = p2.person_id 
   and pd.post_id = p.post_id    
   and pd.department_id = d.department_id 
   and p1.post_id = p.parent_id; 

-- узнать, какие должности есть в каждом подразделении, какие заняты, какие свободны
with cte as (
	select (
	 		 select d.department_name 
	 		   from departments d
	 		  where d.department_id  = pd.department_id 
		   ) as "Департамент",
	       (
	         select p.post_name 
	 		   from posts p
	 		  where p.post_id = pd.post_id 
	       ) as "Должность",
	       (
	         pd.amount -
	         (
	           select count(e.employee_id)
	 		     from employees e
	 		    where e.post_department_id = pd.id_post_department 
	         )
	       ) as "Количество вакантных мест"
    from post_department pd
)
select *
  from cte;

-- узнать, есть ли вакантные должности
with cte as (
	select pd.id_post_department as id_post_department,
	       p.post_name as post_name
      from posts p,
           post_department pd
     where p.post_id = pd.post_id  
)
select cte.post_name as "Вакантная должность"
  from employees e
 right join cte on cte.id_post_department = e.post_department_id 
 where e.employee_id is null; 

-- узнать, сколько подчиненных у руководителя, кто они
with leaders as (
	select pd.post_id as post_id,
	       p2.post_name  as "Должность руководителя"
      from posts p2,
           post_department pd
     where p2.post_id = pd.post_id  
       and pd.is_supervisor = 1
)
select l."Должность руководителя",
	   count(p.post_name) over (partition by l."Должность руководителя") as "Количество подчиненных",
	   p.post_name  as "Должность подчиненного",
	   p3.surname || ' ' || p3."name" as "Имя подчиненного"
  from employees e,
       leaders l,
       posts p,
       post_department pd1,
       persons p3
 where p.parent_id = l.post_id
   and pd1.post_id = p.post_id 
   and e.post_department_id = pd1.id_post_department 
   and p3.person_id = e.person_id; 

-- узнать руководителя подразделения
select d.department_name as "Департамент",
	     p.post_name  as "Должность руководителя",
	     p2.surname || ' ' || p2."name" as "Имя руководителя"
  from post_department pd
  join posts p on pd.post_id = p.post_id 
  join departments d  on d.department_id = pd.department_id 
  left join employees e on e.post_department_id = pd.id_post_department 
  left join persons p2 on p2.person_id = e.person_id 
 where pd.is_supervisor  = 1
  and  d.department_id = ( select d2.department_id from departments d2 where d2.department_name = 'Design');

-- узнать, сколько человек в каждом подразделении, кто они 
with cte as (
	select d.department_name as "Департамент",
	       p.surname || ' ' || p."name" as "Имя сотрудника"
      from employees e,
           post_department pd,
           departments d,
           posts p2,
           persons p
     where e.post_department_id = pd.id_post_department 
   	   and e.person_id = p.person_id 
   	   and p2.post_id = pd.post_id
       and pd.department_id = d.department_id 
)
select cte."Департамент", cte."Имя сотрудника",
	   count(cte."Имя сотрудника") over (partition by cte."Департамент") as "Количество сотрудников" 
  from cte; 

-- узнать, какие люди совмещают должности
select p.surname || ' ' || p."name" as "Имя совместителя"
  from employees e,
  	   persons p
 where e.person_id = p.person_id 
group by p.surname, p."name", e.person_id  
having count(e.employee_id) > 1;  