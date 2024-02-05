# frozen_string_literal: true

FactoryBot.define do
  factory :service_episode, class: 'EMIS::Models::MilitaryServiceEpisode' do
    begin_date { '2001-09-01' }
    end_date { '203-10-01' }
    branch_of_service_code { 'F' }
    discharge_character_of_service_code { 'A' }
  end

  factory :prefill_service_episode, class: 'VAProfile::Prefill::MilitaryInformation' do
    begin_date { '2012-03-02' }
    branch_of_service { 'Army' }
    branch_of_service_code { 'A' }
    character_of_discharge_code { 'A' }
    deployments { [] }
    end_date { '2018-10-31' }
    personnel_category_type_code { 'N' }
    service_type { 'Military Service' }
    termination_reason_code { 'C' }
    termination_reason_text { 'Completion of Active Service period' }
  end
end
