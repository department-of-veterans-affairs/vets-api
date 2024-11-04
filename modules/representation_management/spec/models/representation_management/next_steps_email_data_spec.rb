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

  # describe '#representative_type_humanized' do
  #   it 'returns the humanized and titleized version of the representative type' do
  #     next_steps_email_data = described_class.new(representative_type: 'claims_agent')
  #     expect(next_steps_email_data.representative_type_humanized).to eq('Claims Agent')
  #   end
  # end
  #

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
      expect(next_steps_email_data_attorney.entity_display_type).to eq('Attorney')
      expect(next_steps_email_data_claims_agent.entity_display_type).to eq('Claims Agent')
      expect(next_steps_email_data_representative.entity_display_type).to eq('Representative')
    end

    it 'returns the entity display types for Veteran::Service::Representative' do
      attorney = create(:representative, user_types: ['attorney'])
      claim_agents = create(:representative, user_types: ['claim_agents'])
      veteran_service_officer = create(:representative, user_types: ['veteran_service_officer'])
      next_steps_email_data_attorney = described_class.new(entity_type: 'individual',
                                                           entity_id: attorney.representative_id)
      next_steps_email_data_claim_agents = described_class.new(entity_type: 'individual',
                                                               entity_id: claim_agents.representative_id)
      next_steps_email_data_veteran_service_officer = described_class.new(entity_type: 'individual',
                                                                          entity_id: veteran_service_officer.representative_id)
      expect(next_steps_email_data_attorney.entity_display_type).to eq('Attorney')
      expect(next_steps_email_data_claim_agents.entity_display_type).to eq('Claims Agent')
      expect(next_steps_email_data_veteran_service_officer.entity_display_type).to eq?('Representative')
    end
  end
end
