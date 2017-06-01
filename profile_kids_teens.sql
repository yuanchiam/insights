select

  profile_details.*,
  case when profile_details.profile_group>10000 then 'Both Regular and Kids/Teens'
       when profile_details.profile_group<10000 then 'Kids/Teens Only'
       when profile_details.profile_group=10000 then 'Regular Only'
       end as profile_grp1,
  case when profile_details.profile_group=1 then 'LITTLE_KIDS'
       when profile_details.profile_group=10 then 'OLDER_KIDS'
       when profile_details.profile_group=11 then 'OLDER_KIDS-LITTLE_KIDS'
       when profile_details.profile_group=100 then 'TEENS'
       when profile_details.profile_group=101 then 'TEENS-LITTLE_KIDS'
       when profile_details.profile_group=110 then 'TEENS-OLDER_KIDS'
       when profile_details.profile_group=111 then 'TEENS-OLDER_KIDS-LITTLE_KIDS'
       when profile_details.profile_group=1000 then 'ADULTS'
       when profile_details.profile_group=1001 then 'ADULTS-LITTLE_KIDS'
       when profile_details.profile_group=1010 then 'ADULTS-OLDER_KIDS'
       when profile_details.profile_group=1011 then 'ADULTS-OLDER_KIDS-LITTLE_KIDS'
       when profile_details.profile_group=1100 then 'ADULTS-TEENS'
       when profile_details.profile_group=1101 then 'ADULTS-TEENS-LITTLE_KIDS'
       when profile_details.profile_group=1110 then 'ADULTS-TEENS-OLDER_KIDS'
       when profile_details.profile_group=1111 then 'ADULTS-TEENS-OLDER_KIDS-LITTLE_KIDS'
       end as profile_grp2,
  contact_details.call_center_desc,
  contact_details.country_desc,
  contact_details.contact_origin_country_code,
  contact_details.rcr7,
  contact_details.member_status,
  contact_details.ticket_gate_level0_desc,
  contact_details.ticket_gate_level1_desc,
  contact_details.ticket_gate_level2_desc,
  contact_details.ticket_gate_level3_desc,
  contact_details.contact_subchannel_id,
  contact_details.makegood_amt,
  contact_details.makegood_cnt,
  (coalesce(contact_details.answered_cnt,0)) volume,
  (coalesce(contact_details.member_ticket_cnt,0)) member_tickets,
  (coalesce(contact_details.dsat_survey_response_cnt,0)) survey_responses,
  (coalesce(contact_details.dsat_negative_survey_response_cnt,0)) negative_survey_responses,
  (coalesce(contact_details.has_referral_gate,0)) has_referral_gate,
  (coalesce(contact_details.is_referred_externally,0)) is_referred_externally,
  (((coalesce(contact_details.talk_duration_secs,0)+coalesce(contact_details.acw_duration_secs,0)+coalesce(contact_details.answer_hold_duration_secs,0))/60.0)) handle_time,
  contact_details.contact_start_epoch_utc_ts,
  contact_details.fact_utc_date

from

(select 
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
     else 0 end as profile_group_tmp,
count(*) as count_tmp 
from dse.profile_d
where profile_type='streaming'
and profile_first_use_flag is not null
and membership_status_id=2
-- feb 28, 2017
and create_ts<1488326399000
and is_deleted_by_user=0
and is_deleted_from_source is null
group by account_id,
case when experience_type in ('Unknown','regular') then 10000
     when experience_type='just_for_kids' and maturity_level_desc='ADULTS' then 1000
     when experience_type='just_for_kids' and maturity_level_desc='TEENS' then 100
     when experience_type='just_for_kids' and maturity_level_desc='OLDER_KIDS' then 10
     when experience_type='just_for_kids' and maturity_level_desc='LITTLE_KIDS' then 1
     else 0 end) a
where sum(a.profile_group_tmp)>0
group by account_id) profile_details

join

(select 
 cf.*,
 cc.call_center_desc,
 geo.country_iso_code,
 geo.country_desc,
 case when rcr.contact_code is null then 0 else 1 end as rcr7,
 case when cf.account_id<0 then 'Non-Member' else 'Member' end as member_status 
 from dse.cs_contact_f cf
 join dse.cs_transfer_type_d trt on cf.transfer_type_id = trt.transfer_type_id
 join dse.cs_contact_skill_d r on r.contact_skill_id=cf.contact_skill_id
 join dse.cs_call_center_d cc on cc.call_center_id=cf.call_center_id 
 join dse.account_d acc on acc.account_id=cf.account_id
 join dse.geo_country_d geo on acc.country_iso_code=geo.country_iso_code
 left join (select contact_code from dse.cs_recontact_f
            where days_to_recontact_cnt<=7
            and has_recontact_cnt =1
            and fact_utc_date >= cast(date_format((current_date - interval '3' month ), '%Y%m%d') as bigint)  
            group by contact_code) rcr on cf.contact_code = rcr.contact_code
 where cf.fact_utc_date >= 20170510
 and r.escalation_code not in ('G-Escalation', 'SC-Consult','SC-Escalation','Corp-Escalation')
 and trt.major_transfer_type_desc not in ('TRANSFER_OUT')
 and cf.answered_cnt>0
 and cf.contact_subchannel_id in ('Phone', 'Chat', 'voip','InApp', 'MBChat')
 
) contact_details

on profile_details.account_id=contact_details.account_id
