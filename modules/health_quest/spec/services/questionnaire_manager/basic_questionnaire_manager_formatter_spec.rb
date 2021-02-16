# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter do
  subject { described_class }

  let(:basic_structure) { subject.build([], {}) }

  describe '.build' do
    it 'returns an instance of subject' do
      expect(basic_structure).to be_a(HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to appointments' do
      expect(basic_structure.respond_to?(:appointments)).to eq(true)
    end

    it 'responds to hashed_questionnaires' do
      expect(basic_structure.respond_to?(:hashed_questionnaires)).to eq(true)
    end
  end

  describe '#to_a' do
    let(:appt) { double('Appointment', facility_id: '543', clinic_id: '123456', to_h: { id: '123-abc' }) }
    let(:body) { double('Body', id: '123-abc', title: 'Primary Care') }
    let(:quest) { double('Questionnaire', resource: body) }
    let(:hashed_questionnaires) { { '543/123456' => [quest] } }

    before do
      allow_any_instance_of(subject).to receive(:hashed_questionnaires).and_return(hashed_questionnaires)
      allow_any_instance_of(subject).to receive(:appointments).and_return([appt])
    end

    it 'returns an array of formatted data' do
      response = [
        {
          appointment: { id: '123-abc' },
          questionnaire: [{ id: '123-abc', title: 'Primary Care', questionnaire_response: {} }]
        }
      ]

      expect(basic_structure.to_a).to eq(response)
    end
  end

  describe '#context_keys' do
    let(:appt) { double('Appointment', facility_id: '543', clinic_id: '123456') }

    it 'returns a context_key' do
      expect(basic_structure.context_key(appt)).to eq('543/123456')
    end
  end

  describe '#questions_with_qr' do
    let(:body) { double('Body', id: '123-abc', title: 'Primary Care') }
    let(:quest) { double('Questionnaire', resource: body) }
    let(:data) { { '543/123456' => [quest] } }

    before do
      allow_any_instance_of(subject).to receive(:hashed_questionnaires).and_return(data)
    end

    it 'returns a basic structure' do
      response = [{ id: '123-abc', title: 'Primary Care', questionnaire_response: {} }]

      expect(basic_structure.questions_with_qr('543/123456')).to eq(response)
    end
  end
end
