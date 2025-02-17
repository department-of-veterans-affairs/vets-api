# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter do
  subject { described_class }

  let(:basic_structure) { subject.build({}) }
  let(:appt) do
    [
      double(
        'Appointment',
        id: 'I2-SLRRT64GFG',
        resource: double('Resource',
                         participant: [double('first', actor: double('ref', reference: '/L/I2-LABC'))],
                         to_hash: { id: 'I2-SLRRT64GFG' })
      )
    ]
  end
  let(:hashed_locations) do
    {
      'I2-LABC' => double(
        'Location',
        resource: double('Resource',
                         identifier: [double('first', value: 'vha_442_3049')],
                         to_hash: { id: 'I2-LABC' })
      )
    }
  end
  let(:hashed_organizations) do
    {
      'vha_442' => double(
        'Organization',
        resource: double('Resource', to_hash: { id: 'vha_442' })
      )
    }
  end
  let(:hashed_questionnaires) do
    {
      'vha_442_3049' => [
        double(
          'Questionnaire',
          resource: double(
            'Resource',
            id: 'abc-123-def-455',
            title: 'Primary Care',
            item: [
              double('item', linkId: '01', text: 'one'),
              double('item', linkId: '02', text: 'two')
            ]
          )
        )
      ]
    }
  end

  describe '.build' do
    it 'returns an instance of subject' do
      expect(basic_structure).to be_a(HealthQuest::QuestionnaireManager::BasicQuestionnaireManagerFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to appointments' do
      expect(basic_structure.respond_to?(:appointments)).to be(true)
    end

    it 'responds to hashed_questionnaires' do
      expect(basic_structure.respond_to?(:hashed_questionnaires)).to be(true)
    end
  end

  describe '#to_a' do
    before do
      allow_any_instance_of(subject).to receive(:hashed_locations).and_return(hashed_locations)
      allow_any_instance_of(subject).to receive(:hashed_organizations).and_return(hashed_organizations)
      allow_any_instance_of(subject).to receive(:hashed_questionnaires).and_return(hashed_questionnaires)
      allow_any_instance_of(subject).to receive(:appointments).and_return(appt)
    end

    it 'returns an array of formatted data' do
      response = [
        {
          appointment: { id: 'I2-SLRRT64GFG' },
          organization: { id: 'vha_442' },
          location: { id: 'I2-LABC' },
          questionnaire: [
            {
              id: 'abc-123-def-455',
              title: 'Primary Care',
              item: [{ 'linkId' => '01', 'text' => 'one' }, { 'linkId' => '02', 'text' => 'two' }],
              questionnaire_response: []
            }
          ]
        }.with_indifferent_access
      ]

      expect(basic_structure.to_a).to eq(response)
    end
  end

  describe '#appt_location_id' do
    it 'returns a context_key' do
      expect(basic_structure.appt_location_id(appt.pop)).to eq('I2-LABC')
    end
  end

  describe '#questions_with_qr' do
    before do
      allow_any_instance_of(subject).to receive(:hashed_questionnaires).and_return(hashed_questionnaires)
    end

    it 'returns a basic structure' do
      response = [
        {
          id: 'abc-123-def-455',
          title: 'Primary Care',
          item: [{ 'linkId' => '01', 'text' => 'one' }, { 'linkId' => '02', 'text' => 'two' }],
          questionnaire_response: []
        }.with_indifferent_access
      ]

      expect(basic_structure.questions_with_qr('vha_442_3049')).to eq(response)
    end
  end
end
