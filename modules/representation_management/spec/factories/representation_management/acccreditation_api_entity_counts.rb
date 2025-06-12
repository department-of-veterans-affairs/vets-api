# frozen_string_literal: true

FactoryBot.define do
  factory :accreditation_api_entity_count, class: 'RepresentationManagement::AccreditationApiEntityCount' do
    agents { 100 }
    attorneys { 200 }
    representatives { 300 }
    veteran_service_organizations { 50 }
  end
end
