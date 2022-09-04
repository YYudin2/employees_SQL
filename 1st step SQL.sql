USE employees;

-- Покажите среднюю зарплату сотрудников за каждый год .

/* Комментарий. Т.к. в условиях не указано, как считать "среднюю зарплату" и как точно ее группировать, а базе записи salary есть лишь записи о изменении зарплаты, а не сумма зарплаты за период 
 я делаю несколько допущений, которые усложняют запрос:
 1. В выборке должны быть все года по порядку начиная с первого в базе (реализовано первой частью в СТЕ)
 2. Группировка только по годам, без выделения отдельно сотрудников
 3. Средняя зарплата "внутри" каждого года считается поэтапно: сначала отбираем все зарплаты по сотрудникам, вычисляем количество дней в году сколько ему ее 
 платили (поле days_diff), далее оконнными функциями и агрегацией - взвешиваем по количеству дней и находим средние выплаты по каждому сотруднику.
 5. Затем имея взвешенные зарплаты внутри года - считаем уже средние зарплаты в целом внутри года обычной функцией AVG.
 6. Преобразование числа в decimal с двумя знаками после запятой (мне кажется это тоже допустимо, как и ROUND)
*/
WITH RECURSIVE cte_years AS (
SELECT MIN(YEAR(from_date)) AS stat_year
FROM salaries
UNION ALL
SELECT stat_year + 1 FROM cte_years
WHERE stat_year < 2005
)
SELECT stat_year, CAST((SELECT AVG(avg_salary)
FROM 
( SELECT emp_no, SUM(salary * days_diff / sum_diff ) AS avg_salary
FROM
(SELECT emp_no, salary, days_diff, SUM(days_diff) OVER(PARTITION BY emp_no)  as sum_diff
FROM
(SELECT *, DATEDIFF(IF(YEAR(to_date) = cte_years.stat_year, to_date, MAKEDATE(cte_years.stat_year+1,1)), 
IF(YEAR(from_date) = cte_years.stat_year, from_date, MAKEDATE(cte_years.stat_year,1))) as days_diff
FROM salaries
WHERE YEAR(from_date) <= cte_years.stat_year AND YEAR(to_date) >= cte_years.stat_year
) AS diff_sub) AS sum_diff_sub
GROUP BY emp_no
) AS avg_emp_sub ) AS DECIMAL(8,2))  AS average_salary
  FROM cte_years;
  
  
  -- Покажите среднюю зарплату сотрудников по каждому отделу. Примечание: принять в расчет только текущие отделы и текущую заработную плату.
-- комментарий - группировки по сотрудникам не делаю, т.к. про это не говорится в условии (сказано "по каждому отделу")

SELECT d.dept_no, d.dept_name, CAST(AVG(s.salary) AS DECIMAL(8,2)) AS 'average_current_salary'
FROM departments AS d
		INNER JOIN dept_emp AS de
        ON d.dept_no = de.dept_no AND
        de.to_date > now()
        INNER JOIN salaries AS s
        ON s.emp_no = de.emp_no AND
        s.to_date > now()
GROUP BY d.dept_no, d.dept_name
ORDER BY d.dept_no;

-- Покажите среднюю зарплату сотрудников по каждому отделу за каждый год. Примечание: для средней зарплаты отдела X в году Y 
-- нам нужно взять среднее значение всех зарплат в году Y сотрудников, которые были в отделе X в году Y.

/* Комментарий. делаю все по аналогии с первым заданием. Что касается перечисления лет, оставляю вариант с "статистикой за каждый год до 2005 г.", 
использован Join, для возможности дальнейшей группировки.
Также отмечу, что среднее из таблицы salaries не будет соответствовать результату здесь, т.к. одна и та же зарплата может попадать в 
разные департаменты (переход между ними не всегда означает изменение зарплаты)
*/
   WITH RECURSIVE cte_years AS (
SELECT MIN(YEAR(from_date)) AS stat_year
FROM salaries
UNION ALL
SELECT stat_year + 1 FROM cte_years
WHERE stat_year < 2005
)
SELECT IF(GROUPING(stat_year), 'All Years', stat_year) AS stat_year, 
IF(GROUPING(a.depts), 'All departments', a.depts) AS num_name_dept, 
CAST(AVG(a.salary) AS DECIMAL(8,2)) AS average_salary

FROM cte_years

		JOIN (SELECT salary, s.from_date as sfd, s.to_date as std, de.from_date, de.to_date, s.emp_no, CONCAT( de.dept_no, " ",  d.dept_name) as depts
				FROM salaries AS s
					JOIN dept_emp AS de
					ON s.emp_no = de.emp_no
					AND s.to_date >= de.from_date 
					AND s.from_date <= de.to_date
					JOIN departments AS d
					ON d.dept_no = de.dept_no) AS a 

ON cte_years.stat_year >= YEAR(a.from_date)
AND cte_years.stat_year <= YEAR(a.to_date)
AND cte_years.stat_year >= YEAR(a.sfd)
AND cte_years.stat_year <= YEAR(a.std)

GROUP BY stat_year, a.depts  WITH ROLLUP
ORDER BY stat_year, a.depts ;

-- Покажите для каждого года самый крупный отдел (по количеству сотрудников) в этом году и его среднюю зарплату.

 WITH RECURSIVE cte_years AS (
SELECT MIN(YEAR(from_date)) AS stat_year
FROM salaries
UNION ALL
SELECT stat_year + 1 FROM cte_years
WHERE stat_year < 2005
)
SELECT
stat_year, 
dept_no, 
dept_name , 
average_salary,
Employees
FROM
(SELECT stat_year, 
a.dept_no, 
a.dept_name , 

CAST(AVG(a.salary) AS DECIMAL(8,2)) AS average_salary,
COUNT(DISTINCT(a.emp_no)) AS Employees,
MAX(COUNT(DISTINCT(a.emp_no))) OVER (PARTITION BY stat_year) AS max_employees

FROM cte_years

		JOIN (SELECT salary, s.from_date as sfd, s.to_date as std, de.from_date, de.to_date, s.emp_no, de.dept_no, d.dept_name
				FROM salaries AS s
					JOIN dept_emp AS de
					ON s.emp_no = de.emp_no
					AND s.to_date >= de.from_date 
					AND s.from_date <= de.to_date
					JOIN departments AS d
					ON d.dept_no = de.dept_no) AS a 

ON cte_years.stat_year >= YEAR(a.from_date)
AND cte_years.stat_year <= YEAR(a.to_date)
AND cte_years.stat_year >= YEAR(a.sfd)
AND cte_years.stat_year <= YEAR(a.std)

GROUP BY stat_year, dept_no) AS sub

WHERE employees = max_employees;


-- Покажите подробную информацию о менеджере, который дольше всех исполняет свои обязанности на данный момент.
SELECT e.*, dm.days_at_position, t.title AS current_title, d.dept_name AS current_department, s.salary AS current_salary
FROM employees AS e
	JOIN 
	(SELECT emp_no, dept_no, DATEDIFF(now(), from_date) AS days_at_position
	FROM dept_manager
	WHERE to_date > now()
	ORDER BY days_at_position DESC
	LIMIT 1) AS dm
	ON e.emp_no = dm.emp_no
	JOIN salaries AS s
	ON e.emp_no = s.emp_no
	AND s.to_date > now()
	JOIN titles AS t
	ON e.emp_no = t.emp_no
	AND t.to_date > now()
	JOIN departments AS d
	ON d.dept_no = dm.dept_no
;
