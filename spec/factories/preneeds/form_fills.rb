# frozen_string_literal: true
FactoryGirl.define do
  factory :form_fill, class: Preneeds::FormFill do
    attachment_types { [attributes_for(:preneeds_attachment_type)] }
    branches_of_services { [attributes_for(:branches_of_service)] }
    cemeteries { [attributes_for(:cemetery)] }
    states { [attributes_for(:preneeds_state)] }
    discharge_types { [attributes_for(:discharge_type)] }
  end
end
