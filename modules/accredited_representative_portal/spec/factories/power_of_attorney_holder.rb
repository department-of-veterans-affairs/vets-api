# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_holder, class: 'AccreditedRepresentativePortal::PowerOfAttorneyHolder' do
    type { 'veteran_service_organization' }
    poa_code { "POA#{Faker::Number.number(digits: 3)}" }
    can_accept_digital_poa_requests { true }

    # Ensures FactoryBot uses `new` instead of `create`
    initialize_with { new(type:, poa_code:, can_accept_digital_poa_requests:) }
  end
end
