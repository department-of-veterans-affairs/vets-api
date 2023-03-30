# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::FactoryTypes do
  include HealthQuest::QuestionnaireManager::FactoryTypes

  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838') }

  describe '#patient_type' do
    it 'returns a hash' do
      expect(patient_type).to eq({ user:, resource_identifier: 'patient', api: 'health_api' })
    end
  end

  describe '#questionnaire_type' do
    it 'returns a hash' do
      expect(questionnaire_type).to eq({ user:, resource_identifier: 'questionnaire', api: 'pgd_api' })
    end
  end

  describe '#questionnaire_response_type' do
    it 'returns a hash' do
      expect(questionnaire_response_type)
        .to eq({ user:, resource_identifier: 'questionnaire_response', api: 'pgd_api' })
    end
  end

  describe '#appointment_type' do
    it 'returns a hash' do
      expect(appointment_type).to eq({ user:, resource_identifier: 'appointment', api: 'health_api' })
    end
  end

  describe '#location_type' do
    it 'returns a hash' do
      expect(location_type).to eq({ user:, resource_identifier: 'location', api: 'health_api' })
    end
  end

  describe '#organization_type' do
    it 'returns a hash' do
      expect(organization_type).to eq({ user:, resource_identifier: 'organization', api: 'health_api' })
    end
  end
end
