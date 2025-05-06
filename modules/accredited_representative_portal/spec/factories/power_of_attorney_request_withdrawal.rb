# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_withdrawal,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestWithdrawal' do
    association :resolution, factory: :power_of_attorney_request_resolution

    trait :replacement do
      transient do
        claimant { resolution.power_of_attorney_request.claimant }
      end

      superseding_power_of_attorney_request { build(:power_of_attorney_request, claimant:) }
      type { AccreditedRepresentativePortal::PowerOfAttorneyRequestWithdrawal::Types::REPLACEMENT }
    end
  end
end
