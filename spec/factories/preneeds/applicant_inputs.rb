# frozen_string_literal: true
FactoryGirl.define do
  factory :applicant_input, class: Preneeds::ApplicantInput do
    applicant_email 'happy.gilmore@hotmail.com'
    applicant_phone_number '555-555-5555 - 234'
    applicant_relationship_to_claimant 'self'
    completing_reason "I don't know"

    name { attributes_for :name_input }
    mailing_address { attributes_for :address_input }
  end
end
