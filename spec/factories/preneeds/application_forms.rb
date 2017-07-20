# frozen_string_literal: true
FactoryGirl.define do
  factory :application_form, class: Preneeds::ApplicationForm do
    application_status 'somewhere'
    has_attachments false
    has_currently_buried '1'
    sending_code 'abc'

    applicant { attributes_for :applicant }
    claimant { attributes_for :claimant }
    currently_buried_persons { [attributes_for(:currently_buried_person)] }
    veteran { attributes_for :veteran }
  end
end
