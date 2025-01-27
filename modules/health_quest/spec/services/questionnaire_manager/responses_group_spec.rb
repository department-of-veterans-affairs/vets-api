# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::ResponsesGroup do
  subject { described_class }

  let(:basic_structure) { subject.build({}, {}, {}) }

  describe '.build' do
    it 'returns an instance of subject' do
      expect(basic_structure).to be_a(HealthQuest::QuestionnaireManager::ResponsesGroup)
    end
  end

  describe 'attributes' do
    it 'responds to base_qm' do
      expect(basic_structure.respond_to?(:base_qm)).to be(true)
    end

    it 'responds to hashed_qr' do
      expect(basic_structure.respond_to?(:hashed_qr)).to be(true)
    end

    it 'responds to hashed_sip' do
      expect(basic_structure.respond_to?(:hashed_sip)).to be(true)
    end
  end

  describe '#empty?' do
    it 'is empty' do
      expect(basic_structure.empty?).to be(true)
    end

    context 'when responses present' do
      before do
        allow_any_instance_of(subject).to receive(:qr_responses).and_return([''])
        allow_any_instance_of(subject).to receive(:sip_responses).and_return([''])
      end

      it 'is not empty' do
        expect(basic_structure.empty?).to be(false)
      end
    end
  end

  describe '#appt_id' do
    let(:base_data) { { appointment: { id: 'I2-HSDF567' }.with_indifferent_access } }

    before do
      allow_any_instance_of(subject).to receive(:base_qm).and_return(base_data)
    end

    it 'returns an appt_id' do
      expect(basic_structure.appt_id).to eq('I2-HSDF567')
    end
  end

  describe '#qr_responses' do
    let(:qr) { double('QuestionnaireResponse') }
    let(:hashed_qr) { { 'I2-HSDF567' => [qr] } }
    let(:base_data) { { appointment: { id: 'I2-HSDF567' } }.with_indifferent_access }

    before do
      allow_any_instance_of(subject).to receive(:base_qm).and_return(base_data)
      allow_any_instance_of(subject).to receive(:hashed_qr).and_return(hashed_qr)
    end

    it 'returns a questionnaire response array' do
      expect(basic_structure.qr_responses).to eq([qr])
    end
  end

  describe '#sip_responses' do
    let(:sip) { double('InProgressForm') }
    let(:hashed_sip) { { 'I2-HSDF567' => [sip] } }
    let(:base_data) { { appointment: { id: 'I2-HSDF567' } }.with_indifferent_access }

    before do
      allow_any_instance_of(subject).to receive(:base_qm).and_return(base_data)
      allow_any_instance_of(subject).to receive(:hashed_sip).and_return(hashed_sip)
    end

    it 'returns a sip array' do
      expect(basic_structure.sip_responses).to eq([sip])
    end
  end

  describe '#appt_questionnaires' do
    let(:base_data) do
      {
        appointment: { id: 'I2-HSDF567' },
        questionnaire: [{ id: '123-abc', title: 'The Questionnaire' }]
      }.with_indifferent_access
    end

    before do
      allow_any_instance_of(subject).to receive(:base_qm).and_return(base_data)
    end

    it 'returns a hash' do
      response = { '123-abc' => { id: '123-abc', title: 'The Questionnaire' }.with_indifferent_access }

      expect(basic_structure.appt_questionnaires).to eq(response)
    end
  end
end
