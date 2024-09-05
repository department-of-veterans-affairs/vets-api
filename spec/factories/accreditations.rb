# frozen_string_literal: true

FactoryBot.define do
  factory :accreditation do
    accredited_individual { create(:accredited_individual) }
    accredited_organization { create(:accredited_organization) }
    can_accept_reject_poa { true }
  end
end
