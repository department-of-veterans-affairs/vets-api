# frozen_string_literal: true
FactoryGirl.define do
  factory :service_record, class: Preneeds::ServiceRecord do
    branch_of_service 'AF' # Air Force
    discharge_type '1' # Honorably
    entered_on_duty_date '2001-01-31T10:00:00'
    highest_rank 'GEN'
    national_guard_state 'N'
    release_from_duty_date '2001-01-31T10:00:00'
  end
end
