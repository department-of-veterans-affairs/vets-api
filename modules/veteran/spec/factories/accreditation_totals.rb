# frozen_string_literal: true

FactoryBot.define do
  factory :accreditation_total, class: 'Veteran::AccreditationTotal' do
    attorneys { 100 }
    claims_agents { 50 }
    vso_representatives { 75 }
    vso_organizations { 20 }
  end
end
