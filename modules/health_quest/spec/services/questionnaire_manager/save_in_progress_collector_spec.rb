# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::SaveInProgressCollector do
  subject { described_class }

  let(:group) { HealthQuest::QuestionnaireManager::ResponsesGroup }
  let(:basic_structure) { subject.build(group.build({}, {}, {})) }

  describe 'constants' do
    it 'has an ID_MATCHER' do
      expect(subject::ID_MATCHER).to eq(/_([a-zA-Z0-9-]+)\z/i)
    end

    it 'has an IN_PROGRESS_STATUS' do
      expect(subject::IN_PROGRESS_STATUS).to eq('in-progress')
    end
  end

  describe '.build' do
    it 'returns an instance of subject' do
      expect(basic_structure).to be_a(HealthQuest::QuestionnaireManager::SaveInProgressCollector)
    end
  end

  describe 'attributes' do
    it 'responds to groups' do
      expect(basic_structure.respond_to?(:groups)).to be(true)
    end
  end

  describe '#collect' do
    let(:sip_responses) { [double('InProgressForm', form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55_abc-123')] }
    let(:appt_questionnaires) do
      { 'abc-123' => { id: 'abc-123', title: 'The Questionnaire', questionnaire_response: [] } }
    end

    before do
      allow_any_instance_of(group).to receive(:appt_questionnaires).and_return(appt_questionnaires)
      allow_any_instance_of(group).to receive(:sip_responses).and_return(sip_responses)
    end

    it 'sets the in-progress status' do
      response = {
        'abc-123' => {
          id: 'abc-123',
          title: 'The Questionnaire',
          questionnaire_response: [
            {
              form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55_abc-123',
              status: 'in-progress'
            }.with_indifferent_access
          ]
        }
      }

      basic_structure.collect

      expect(appt_questionnaires).to eq(response)
    end
  end
end
