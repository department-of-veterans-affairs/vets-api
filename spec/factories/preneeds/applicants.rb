# frozen_string_literal: true
FactoryGirl.define do
  factory :applicant, class: Preneeds::Applicant do
    applicant_email 'hg@hotmail.com'
    applicant_phone_number '555-555-5555 - 234'
    applicant_relationship_to_claimant 'Self'
    completing_reason "I don't know"

    name { attributes_for :name }
    mailing_address { attributes_for :address }
  end
end
