# frozen_string_literal: true

FactoryBot.define do
  factory :saved_claim_claimant_representative,
          class: 'AccreditedRepresentativePortal::SavedClaimClaimantRepresentative' do
    saved_claim { create(:saved_claim_benefits_intake) }
    claimant_id { SecureRandom.uuid }
    claimant_type { 'veteran' }
    power_of_attorney_holder_type { 'veteran_service_organization' }
    power_of_attorney_holder_poa_code { '067' }
    accredited_individual_registration_number { '357458' }
  end
end
