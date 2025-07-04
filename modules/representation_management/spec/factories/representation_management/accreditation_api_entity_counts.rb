# frozen_string_literal: true

FactoryBot.define do
  factory :accreditation_api_entity_count, class: 'RepresentationManagement::AccreditationApiEntityCount' do
    agents { 10 }
    attorneys { 10 }
    representatives { 10 }
    veteran_service_organizations { 10 }
  end
end
