# frozen_string_literal: true
FactoryGirl.define do
  factory :application_form, class: Preneeds::ApplicationForm do
    has_attachments false
    has_currently_buried '1'

    applicant { attributes_for :applicant }
    claimant { attributes_for :claimant }
    currently_buried_persons { [attributes_for(:currently_buried)] }
    veteran { attributes_for :veteran }
  end
end
