# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::NextStepsEmailData, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_presence_of(:email_address) }
    it { expect(subject).to validate_presence_of(:first_name) }
    it { expect(subject).to validate_presence_of(:form_name) }
    it { expect(subject).to validate_presence_of(:form_number) }
    it { expect(subject).to validate_presence_of(:entity_type) }
    it { expect(subject).to validate_presence_of(:entity_id) }
  end

  describe '#entity' do
    it 'returns the entity for accredited_individual' do
      accredited_individual = create(:accredited_individual)
      next_steps_email_data = described_class.new(entity_type: 'individual',
                                                  entity_id: accredited_individual.id)
      expect(next_steps_email_data.entity).to eq(accredited_individual)
    end

    it 'returns the entity for veteran_service_representative' do
      veteran_service_representative = create(:representative)
      next_steps_email_data = described_class.new(entity_type: 'individual',
                                                  entity_id: veteran_service_representative.representative_id)
      expect(next_steps_email_data.entity).to eq(veteran_service_representative)
    end

    it 'returns the entity for organization' do
      organization = create(:organization)
      next_steps_email_data = described_class.new(entity_type: 'organization',
                                                  entity_id: organization.poa)
      expect(next_steps_email_data.entity).to eq(organization)
    end

    it 'returns the entity for accredited_organization' do
      accredited_organization = create(:accredited_organization)
      next_steps_email_data = described_class.new(entity_type: 'organization',
                                                  entity_id: accredited_organization.id)
      expect(next_steps_email_data.entity).to eq(accredited_organization)
    end

    it 'returns nil if entity is not found' do
      next_steps_email_data = described_class.new(entity_type: 'individual', entity_id: 1)
      expect(next_steps_email_data.entity).to be_nil
    end
  end

  describe '#entity_display_type' do
    it 'returns the entity display types for AccreditedIndividual' do
      attorney = create(:accredited_individual, individual_type: 'attorney')
      claims_agent = create(:accredited_individual, individual_type: 'claims_agent')
      representative = create(:accredited_individual, individual_type: 'representative')
      next_steps_email_data_attorney = described_class
                                       .new(entity_type: 'individual', entity_id: attorney.id)
      next_steps_email_data_claims_agent = described_class
                                           .new(entity_type: 'individual', entity_id: claims_agent.id)
      next_steps_email_data_representative = described_class
                                             .new(entity_type: 'individual', entity_id: representative.id)
      expect(next_steps_email_data_attorney.entity_display_type).to eq('attorney')
      expect(next_steps_email_data_claims_agent.entity_display_type).to eq('claims agent')
      expect(next_steps_email_data_representative.entity_display_type).to eq('VSO representative')
    end

    it 'returns the entity display types for Veteran::Service::Representative' do
      attorney = create(:representative, first_name: 'Bob', user_types: ['attorney'])
      claim_agents = create(:representative, first_name: 'Bobby', user_types: ['claim_agents'],
                                             representative_id: '12345')
      veteran_service_officer = create(:representative, first_name: 'Bobbie', user_types: ['veteran_service_officer'],
                                                        representative_id: '123456')
      next_steps_email_data_attorney = described_class.new(entity_type: 'individual',
                                                           entity_id: attorney.representative_id)
      next_steps_email_data_claim_agents = described_class.new(entity_type: 'individual',
                                                               entity_id: claim_agents.representative_id)
      next_steps_email_data_vso = described_class.new(entity_type: 'individual',
                                                      entity_id: veteran_service_officer.representative_id)
      expect(next_steps_email_data_attorney.entity_display_type).to eq('attorney')
      expect(next_steps_email_data_claim_agents.entity_display_type).to eq('claims agent')
      expect(next_steps_email_data_vso.entity_display_type).to eq('VSO representative')
    end

    it 'returns the entity display types for Veteran Service Organization' do
      organization = create(:organization)
      accredited_organization = create(:accredited_organization)
      next_steps_email_data_organization = described_class.new(entity_type: 'organization',
                                                               entity_id: organization.poa)
      next_steps_email_data_accredited_organization = described_class.new(entity_type: 'organization',
                                                                          entity_id: accredited_organization.id)
      expect(next_steps_email_data_organization.entity_display_type).to eq('Veterans Service Organization')
      expect(next_steps_email_data_accredited_organization.entity_display_type).to eq('Veterans Service Organization')
    end
  end

  describe '#entity_name' do
    it 'returns the entity name for accredited_individual' do
      accredited_individual = create(:accredited_individual)
      next_steps_email_data = described_class.new(entity_type: 'individual',
                                                  entity_id: accredited_individual.id)
      expect(next_steps_email_data.entity_name).to eq(accredited_individual.full_name)
    end

    it 'returns the entity name for veteran_service_representative' do
      veteran_service_representative = create(:representative)
      next_steps_email_data = described_class.new(entity_type: 'individual',
                                                  entity_id: veteran_service_representative.representative_id)
      expect(next_steps_email_data.entity_name).to eq(veteran_service_representative.full_name)
    end

    it 'returns the entity name for organization' do
      organization = create(:organization)
      next_steps_email_data = described_class.new(entity_type: 'organization',
                                                  entity_id: organization.poa)
      expect(next_steps_email_data.entity_name).to eq(organization.name)
    end
  end
end
