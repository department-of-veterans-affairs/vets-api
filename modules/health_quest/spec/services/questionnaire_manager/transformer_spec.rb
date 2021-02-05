# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Transformer do
  subject { described_class }

  let(:wip_hash) { { data: 'WIP' } }

  describe '.build' do
    it 'is an instance of the subject' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe '#combine' do
    it 'returns combined data' do
      # This will return a fully fleshed out hash with all the relevant data once the ticket is completed
      expect(subject.build.combine(nil)).to eq(wip_hash)
    end
  end

  describe '#get_use_context' do
    let(:data) do
      [
        double('Appointments', facility_id: '123', clinic_id: '54679'),
        double('Appointments', facility_id: '789', clinic_id: '98741')
      ]
    end

    it 'returns a formatted use-context string' do
      expect(subject.build.get_use_context(data)).to eq('venue$123/54679,venue$789/98741')
    end
  end
end
