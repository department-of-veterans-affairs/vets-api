# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::QuestionnaireResponseCollector do
  subject { described_class }

  let(:group) { HealthQuest::QuestionnaireManager::ResponsesGroup }
  let(:basic_structure) { subject.build(group.build({}, {}, {})) }

  describe 'constants' do
    it 'has an ID_MATCHER' do
      expect(subject::ID_MATCHER).to eq(%r{Questionnaire/([a-z0-9-]+)\z}i)
    end
  end

  describe '.build' do
    it 'returns an instance of subject' do
      expect(basic_structure).to be_a(HealthQuest::QuestionnaireManager::QuestionnaireResponseCollector)
    end
  end

  describe 'attributes' do
    it 'responds to groups' do
      expect(basic_structure.respond_to?(:groups)).to be(true)
    end
  end

  describe '#collect' do
    let(:qr_responses) do
      [
        double(
          'QuestionnaireResponse',
          resource: double('Resource',
                           id: 'abc-123-def-455',
                           status: 'completed',
                           authored: '2021-02-01',
                           questionnaire: 'Questionnaire/abc-123-def-455')
        )
      ]
    end
    let(:appt_questionnaires) do
      { 'abc-123-def-455' => { id: 'abc-123-def-455', title: 'The Questionnaire', questionnaire_response: [] } }
    end

    before do
      allow_any_instance_of(group).to receive(:appt_questionnaires).and_return(appt_questionnaires)
      allow_any_instance_of(group).to receive(:qr_responses).and_return(qr_responses)
    end

    it 'sets the questionnaire response data' do
      response = {
        'abc-123-def-455' => {
          id: 'abc-123-def-455',
          title: 'The Questionnaire',
          questionnaire_response: [
            { id: 'abc-123-def-455', status: 'completed', submitted_on: '2021-02-01' }.with_indifferent_access
          ]
        }
      }

      basic_structure.collect

      expect(appt_questionnaires).to eq(response)
    end
  end
end
