# frozen_string_literal: true

FactoryBot.define do
  factory :ar_power_of_attorney_form, class: 'AccreditedRepresentativePortal::PowerOfAttorneyForm' do
    association :power_of_attorney_request, factory: :ar_power_of_attorney_request

    data_ciphertext { 'sensitive_data' }
    city_bidx { 'city_index' }
    state_bidx { 'state_index' }
    zipcode_bidx { 'zipcode_index' }
  end
end
