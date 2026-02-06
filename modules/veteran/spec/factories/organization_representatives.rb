# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_service_organization_representative,
          class: 'Veteran::Service::OrganizationRepresentative' do
    association :representative, factory: :veteran_service_representative
    association :organization, factory: :veteran_service_organization

    # join table stores these columns; set explicitly so it’s not relying on AR magic
    representative_id { representative.representative_id }
    organization_poa { organization.poa }

    acceptance_mode { 'no_acceptance' }
  end
end