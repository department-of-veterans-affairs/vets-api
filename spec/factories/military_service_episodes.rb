
# frozen_string_literal: true
FactoryGirl.define do
  factory :service_episode, class: 'EMIS::Models::MilitaryServiceEpisode' do
    begin_date '2001-09-01'
    end_date '203-10-01'
    branch_of_service_code 'F'
    discharge_character_of_service_code 'A'
  end
end
