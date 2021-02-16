# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Transformer do
  subject { described_class }

  describe '.manufacture' do
    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'is an instance of the subject' do
      expect(subject.manufacture({})).to be_an_instance_of(described_class)
    end
  end

  describe 'attributes' do
    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'responds to appointments' do
      expect(subject.manufacture({}).respond_to?(:appointments)).to be(true)
    end

    it 'responds to questionnaires' do
      expect(subject.manufacture({}).respond_to?(:questionnaires)).to be(true)
    end

    it 'responds to questionnaire_responses' do
      expect(subject.manufacture({}).respond_to?(:questionnaire_responses)).to be(true)
    end

    it 'responds to save_in_progress' do
      expect(subject.manufacture({}).respond_to?(:save_in_progress)).to be(true)
    end

    it 'responds to hashed_questionnaires' do
      expect(subject.manufacture({}).respond_to?(:hashed_questionnaires)).to be(true)
    end

    it 'responds to hashed_questionnaire_responses' do
      expect(subject.manufacture({}).respond_to?(:hashed_questionnaire_responses)).to be(true)
    end

    it 'responds to hashed_save_in_progress' do
      expect(subject.manufacture({}).respond_to?(:hashed_save_in_progress)).to be(true)
    end
  end

  describe '#hashed_save_in_progress' do
    let(:sip_data) do
      [
        OpenStruct.new(
          id: 1,
          form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_abc-123-def-455'
        ),
        OpenStruct.new(
          id: 2,
          form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_ccc-123-ddd-455'
        )
      ]
    end
    let(:formatted_hash) do
      {
        'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000' => [
          OpenStruct.new(
            id: 1,
            form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_abc-123-def-455'
          ),
          OpenStruct.new(
            id: 2,
            form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_ccc-123-ddd-455'
          )
        ]
      }
    end

    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
    end

    it 'returns a hash' do
      expect(subject.manufacture(save_in_progress: sip_data).hashed_save_in_progress).to eq(formatted_hash)
    end
  end

  describe '#hashed_questionnaire_responses' do
    let(:questionnaire_responses_data) do
      [
        OpenStruct.new(
          id: 1,
          subject: OpenStruct.new(reference: 'Appointment/I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB')
        ),
        OpenStruct.new(
          id: 2,
          subject: OpenStruct.new(reference: 'Appointment/I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB')
        )
      ]
    end
    let(:formatted_hash) do
      {
        'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB' => [
          OpenStruct.new(
            id: 1,
            subject: OpenStruct.new(reference: 'Appointment/I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB')
          ),
          OpenStruct.new(
            id: 2,
            subject: OpenStruct.new(reference: 'Appointment/I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB')
          )
        ]
      }
    end

    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'returns a hash' do
      expect(subject.manufacture(questionnaire_responses: questionnaire_responses_data).hashed_questionnaire_responses)
        .to eq(formatted_hash)
    end
  end

  describe '#hashed_questionnaires' do
    let(:questionnaire_data) do
      [
        OpenStruct.new(
          id: 1,
          to_hash: { 'resource' => { 'useContext' => [{
            'valueCodeableConcept' => { 'coding' => [{ 'code' => '123/45678' }] }
          }] } }
        ),
        OpenStruct.new(
          id: 2,
          to_hash: { 'resource' => { 'useContext' => [{
            'valueCodeableConcept' => { 'coding' => [{ 'code' => '123/45678' }] }
          }] } }
        )
      ]
    end
    let(:formatted_hash) do
      {
        '123/45678' => [
          OpenStruct.new(
            id: 1,
            to_hash: { 'resource' => { 'useContext' => [{
              'valueCodeableConcept' => { 'coding' => [{ 'code' => '123/45678' }] }
            }] } }
          ),
          OpenStruct.new(
            id: 2,
            to_hash: { 'resource' => { 'useContext' => [{
              'valueCodeableConcept' => { 'coding' => [{ 'code' => '123/45678' }] }
            }] } }
          )
        ]
      }
    end

    before do
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'returns a hash' do
      expect(subject.manufacture(questionnaires: questionnaire_data).hashed_questionnaires).to eq(formatted_hash)
    end
  end

  describe '#combine' do
    let(:data) do
      [
        double(
          'Appointments',
          id: 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
          facility_id: '534',
          clinic_id: '12975',
          to_h: { id: 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
                  attributes: { facility_id: '534', clinic_id: '12975' } }
        ),
        double(
          'Appointments',
          id: 'I2-DDRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
          facility_id: '789',
          clinic_id: '98741',
          to_h: { id: 'I2-DDRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ000',
                  attributes: { facility_id: '789', clinic_id: '98741' } }
        )
      ]
    end
    let(:questions_hash) do
      {
        '534/12975' => [
          double('Questionnaire', resource: double('Resource', id: 'abc-123-def-455', title: 'Primary Care'))
        ]
      }
    end

    context 'when no sip and no questionnaire response data' do
      let(:response) do
        {
          data: [
            {
              appointment: {
                id: 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
                attributes: {
                  facility_id: '534',
                  clinic_id: '12975'
                }
              },
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: {}
                }
              ]
            }
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:appointments).and_return(data)
        allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return(questions_hash)
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
      end

      it 'returns appointment with questionnaire and empty questionnaire response' do
        expect(subject.manufacture({}).combine).to eq(response)
      end
    end

    context 'when questionnaire response data and no sip' do
      let(:questionnaire_response_hash) do
        {
          'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000' => [
            double(
              'QuestionnaireResponse',
              resource: double('Resource',
                               id: 'abc-123-def-455',
                               status: 'completed',
                               authored: '2021-02-01',
                               questionnaire: 'Questionnaire/abc-123-def-455')
            ),
            double(
              'QuestionnaireResponse',
              resource: double('Resource',
                               id: 'abc-321-kju-554',
                               status: 'completed',
                               authored: '2021-02-01',
                               questionnaire: 'Questionnaire/abc-321-kju-554')
            )
          ]
        }
      end
      let(:response) do
        {
          data: [
            {
              appointment: {
                id: 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
                attributes: {
                  facility_id: '534',
                  clinic_id: '12975'
                }
              },
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: {
                    id: 'abc-123-def-455',
                    status: 'completed',
                    submitted_on: '2021-02-01'
                  }
                }
              ]
            }
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:appointments).and_return(data)
        allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return(questions_hash)
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id)
          .and_return(questionnaire_response_hash)
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
      end

      it 'returns appointment with questionnaire and matching questionnaire response' do
        expect(subject.manufacture({}).combine).to eq(response)
      end
    end

    context 'when sip and no questionnaire response data' do
      let(:sip_hash) do
        {
          'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000' => [
            double('SaveInProgress',
                   form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_abc-123-def-455'),
            double('SaveInProgress',
                   form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_ccc-123-ddd-455')
          ]
        }
      end
      let(:response) do
        {
          data: [
            {
              appointment: {
                id: 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
                attributes: {
                  facility_id: '534',
                  clinic_id: '12975'
                }
              },
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: {
                    status: 'in-progress'
                  }
                }
              ]
            }
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:appointments).and_return(data)
        allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return(questions_hash)
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return(sip_hash)
      end

      it 'returns appointment with questionnaire and matching questionnaire response' do
        expect(subject.manufacture({}).combine).to eq(response)
      end
    end

    context 'when questionnaire response and sip data' do
      let(:questions_hash) do
        {
          '534/12975' => [
            double('Questionnaire', resource: double('Resource', id: 'abc-123-def-455', title: 'Primary Care')),
            double('Questionnaire', resource: double('Resource', id: 'ccc-123-ddd-455', title: 'Donut Intake'))
          ]
        }
      end
      let(:questionnaire_response_hash) do
        {
          'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000' => [
            double(
              'QuestionnaireResponse',
              resource: double('Resource',
                               id: 'abc-123-def-455',
                               status: 'completed',
                               authored: '2021-02-01',
                               questionnaire: 'Questionnaire/abc-123-def-455')
            )
          ]
        }
      end
      let(:sip_hash) do
        {
          'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000' => [
            double('SaveInProgress',
                   form_id: 'HC-QSTNR_I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000_ccc-123-ddd-455')
          ]
        }
      end
      let(:response) do
        {
          data: [
            {
              appointment: {
                id: 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
                attributes: {
                  facility_id: '534',
                  clinic_id: '12975'
                }
              },
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: {
                    id: 'abc-123-def-455',
                    status: 'completed',
                    submitted_on: '2021-02-01'
                  }
                },
                {
                  id: 'ccc-123-ddd-455',
                  title: 'Donut Intake',
                  questionnaire_response: {
                    status: 'in-progress'
                  }
                }
              ]
            }
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:appointments).and_return(data)
        allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return(questions_hash)
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id)
          .and_return(questionnaire_response_hash)
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return(sip_hash)
      end

      it 'returns appointment with questionnaire and matching questionnaire response' do
        expect(subject.manufacture({}).combine).to eq(response)
      end
    end
  end
end
