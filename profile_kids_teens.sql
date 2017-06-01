select 
account_id,
from_unixtime(CAST(create_ts/1000 as BIGINT), 'yyyy-MM-dd') as create_time,
experience_type,
maturity_level_desc,
case when experience_type in ('Unknown','regular') then 10000
     when experience_type='just_for_kids' and maturity_level_desc='ADULTS' then 1000
     when experience_type='just_for_kids' and maturity_level_desc='TEENS' then 100
     when experience_type='just_for_kids' and maturity_level_desc='OLDER_KIDS' then 10
     when experience_type='just_for_kids' and maturity_level_desc='LITTLE_KIDS' then 1
     else 0 end as profile_group
--82,080,675
--select count(*) -- member_since_ts<1488326399000
--129,638,628
--select count(*)
select count(*), experience_type,
maturity_level_desc
from dse.profile_d
where profile_type='streaming'
and profile_first_use_flag is not null
and membership_status_id=2
-- feb 28, 2017
and member_since_ts<1488326399000
and is_deleted_by_user=0
and is_deleted_from_source is null
group by experience_type,
maturity_level_desc
