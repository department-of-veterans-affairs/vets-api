# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_decision,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' do
    id { Faker::Internet.uuid }
    association :creator, factory: :user_account
    type { 'Approval' }
  end
end
