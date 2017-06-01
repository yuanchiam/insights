
select 
a.account_id,
sum(a.profile_group_tmp) as profile_group
from
(select 
account_id,
--from_unixtime(CAST(create_ts/1000 as BIGINT), 'yyyyMMdd') as create_time,
case when experience_type in ('Unknown','regular') then 10000
     when experience_type='just_for_kids' and maturity_level_desc='ADULTS' then 1000
     when experience_type='just_for_kids' and maturity_level_desc='TEENS' then 100
     when experience_type='just_for_kids' and maturity_level_desc='OLDER_KIDS' then 10
     when experience_type='just_for_kids' and maturity_level_desc='LITTLE_KIDS' then 1
     else 0 end as profile_group_tmp
from dse.profile_d
where profile_type='streaming'
and profile_first_use_flag is not null
and membership_status_id=2
-- feb 28, 2017
and create_ts<1488326399000
and is_deleted_by_user=0
and is_deleted_from_source is null) a
group by account_id
