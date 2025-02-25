# frozen_string_literal: true

FactoryBot.define do
  factory :applicant, class: 'Preneeds::Applicant' do
    applicant_email { 'hg@hotmail.com' }
    applicant_phone_number { '555-555-5555 - 234' }
    applicant_relationship_to_claimant { 'Self' }
    completing_reason { "I don't know" }

    name { attributes_for(:full_name) }
    mailing_address { attributes_for(:address) }
  end

  factory :applicant_foreign_address, parent: :applicant do
    mailing_address { attributes_for(:foreign_address) }
  end
end
