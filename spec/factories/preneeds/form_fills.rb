# frozen_string_literal: true
FactoryGirl.define do
  factory :form_fill, class: Preneeds::FormFill do
    attachment_types { [build(:preneeds_attachment_type)] }
    branches_of_services { [build(:branches_of_service)] }
    cemeteries { [build(:cemetery)] }
    states { [build(:preneeds_state)] }
    discharge_types { [build(:discharge_type)] }
  end
end
