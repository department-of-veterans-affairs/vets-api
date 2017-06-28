# frozen_string_literal: true
FactoryGirl.define do
  factory :service_record_input, class: Preneeds::ServiceRecordInput do
    branch_of_service_code 'AF' # Air Force
    discharge_type '1' # Honorably
  end
end
