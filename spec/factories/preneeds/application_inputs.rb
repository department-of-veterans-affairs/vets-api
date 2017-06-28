# frozen_string_literal: true
FactoryGirl.define do
  factory :application_input, class: Preneeds::ApplicationInput do
    has_attachments false
    has_currently_buried '1'

    applicant { attributes_for :applicant_input }
    claimant { attributes_for :claimant_input }
    currently_buried_persons { [attributes_for(:currently_buried_input)] }
    veteran { attributes_for :veteran_input }
  end
end
