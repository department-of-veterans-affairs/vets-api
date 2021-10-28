# frozen_string_literal: true

FactoryBot.define do
  factory :caregivers_assistance_claim, class: 'SavedClaim::CaregiversAssistanceClaim' do
    form { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json }
  end
end
