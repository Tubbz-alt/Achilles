-- 630	Number and proportion of look back days by procedure_concept_id.
-- NB: Look back days (stratum_3) are limited to the Atlas defaults: 0,1,7,14,21,30,60,90,120,180,365,548,730,1095.
--     Proportion (stratum_2) represents the proportion of people with a given procedure that have at least
--     N days of look back.

--HINT DISTRIBUTE_ON_KEY(stratum_1)
  with po as (
-- Find earliest occurrence of each concept_id, person_id pair  
select procedure_concept_id, person_id, min(procedure_date) procedure_date
  from @cdmDatabaseSchema.procedure_occurrence
 group by procedure_concept_id,person_id
), lookback as (
-- Count the concept_id, look back day pairs 
select po.procedure_concept_id,
       datediff(d,op.observation_period_start_date,po.procedure_date) as lookback_days,
       count_big(*) as count_value
  from @cdmDatabaseSchema.observation_period op join po
    on po.person_id = op.person_id
 where op.observation_period_start_date <= po.procedure_date
 group by po.procedure_concept_id, datediff(d,op.observation_period_start_date,po.procedure_date)
), lookback_prop as (
-- Compute the proportion of people with N days of look back per concept_id
select *,
       1.0*sum(count_value)over(
	            partition by procedure_concept_id 
				    order by lookback_days 
	                 rows between current row and unbounded following)/sum(count_value)over() as proportion       
  from lookback
)
-- To avoid flooding Achilles, limit look back days to the Atlas defaults
select 630 as analysis_id,
       cast(procedure_concept_id   as varchar(255)) as stratum_1,
       cast(proportion             as varchar(255)) as stratum_2,
       cast(lookback_days          as varchar(255)) as stratum_3,
       cast(null                   as varchar(255)) as stratum_4,
       cast(null                   as varchar(255)) as stratum_5,
       count_value
  into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_630
  from lookback_prop 
 where lookback_days in (0,1,7,14,21,30,60,90,120,180,365,548,730,1095); 
   