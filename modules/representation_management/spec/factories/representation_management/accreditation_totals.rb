# frozen_string_literal: true

FactoryBot.define do
  factory :representation_management_accreditation_total, class: 'RepresentationManagement::AccreditationTotal' do
    attorneys { 100 }
    claims_agents { 50 }
    vso_representatives { 75 }
    vso_organizations { 20 }
  end
end
