# frozen_string_literal: true

FactoryBot.define do
  factory :claimant, class: 'Preneeds::Claimant' do
    date_of_birth { '2001-01-31' }
    desired_cemetery { '400' } # Alabama National VA Cemetery
    relationship_to_vet { '1' } # self
    ssn { '123456789' }
    email { 'a@b.com' }
    phone_number { '1234567890' }

    name { attributes_for(:full_name) }
    address { attributes_for(:address) }
  end

  factory :claimant_foreign_address, parent: :claimant do
    address { attributes_for(:foreign_address) }
  end
end
