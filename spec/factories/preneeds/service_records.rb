# frozen_string_literal: true
FactoryGirl.define do
  factory :service_record, class: Preneeds::ServiceRecord do
    service_branch 'AF' # Air Force
    discharge_type 'honorable'
    highest_rank 'GEN'
    national_guard_state 'N'

    date_range { attributes_for :date_range }
  end
end
