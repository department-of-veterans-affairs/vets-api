# frozen_string_literal: true
FactoryGirl.define do
  factory :claimant_input, class: Preneeds::ClaimantInput do
    date_of_birth '2001-01-31'
    desired_cemetery 400 # Alabama National VA Cemetery
    relationship_to_vet 1 # self
    ssn '123-45-6789'

    name { attributes_for :name_input }
    address { attributes_for :address_input }
  end
end
