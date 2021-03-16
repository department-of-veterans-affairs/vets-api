# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::Transformer do
  subject { described_class }

  let(:default_options) do
    {
      lighthouse_appointments: [],
      locations: [],
      organizations: [],
      questionnaires: [],
      questionnaire_responses: [],
      save_in_progress: []
    }
  end

  describe '.manufacture' do
    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'is an instance of the subject' do
      expect(subject.manufacture(default_options)).to be_an_instance_of(described_class)
    end
  end

  describe 'attributes' do
    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'responds to appointments' do
      expect(subject.manufacture(default_options).respond_to?(:appointments)).to be(true)
    end

    it 'responds to locations' do
      expect(subject.manufacture(default_options).respond_to?(:locations)).to be(true)
    end

    it 'responds to organizations' do
      expect(subject.manufacture(default_options).respond_to?(:organizations)).to be(true)
    end

    it 'responds to questionnaires' do
      expect(subject.manufacture(default_options).respond_to?(:questionnaires)).to be(true)
    end

    it 'responds to questionnaire_responses' do
      expect(subject.manufacture(default_options).respond_to?(:questionnaire_responses)).to be(true)
    end

    it 'responds to save_in_progress' do
      expect(subject.manufacture(default_options).respond_to?(:save_in_progress)).to be(true)
    end

    it 'responds to hashed_questionnaires' do
      expect(subject.manufacture(default_options).respond_to?(:hashed_questionnaires)).to be(true)
    end

    it 'responds to hashed_questionnaire_responses' do
      expect(subject.manufacture(default_options).respond_to?(:hashed_questionnaire_responses)).to be(true)
    end

    it 'responds to hashed_save_in_progress' do
      expect(subject.manufacture(default_options).respond_to?(:hashed_save_in_progress)).to be(true)
    end
  end

  describe '#hashed_save_in_progress' do
    let(:sip_data) do
      [
        OpenStruct.new(
          id: 1,
          form_id: 'HC-QSTNR_I2-SLRRT64GFG_abc-123-def-455'
        ),
        OpenStruct.new(
          id: 2,
          form_id: 'HC-QSTNR_I2-SLRRT64GFG_ccc-123-ddd-455'
        )
      ]
    end
    let(:formatted_hash) do
      {
        'I2-SLRRT64GFG' => [
          OpenStruct.new(
            id: 1,
            form_id: 'HC-QSTNR_I2-SLRRT64GFG_abc-123-def-455'
          ),
          OpenStruct.new(
            id: 2,
            form_id: 'HC-QSTNR_I2-SLRRT64GFG_ccc-123-ddd-455'
          )
        ]
      }
    end

    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
    end

    it 'returns a hash' do
      expect(subject.manufacture(default_options.merge(save_in_progress: sip_data)).hashed_save_in_progress)
        .to eq(formatted_hash)
    end
  end

  describe '#hashed_questionnaire_responses' do
    let(:reference) { OpenStruct.new(reference: 'Appointment/I2-SLRRT64GFG') }
    let(:questionnaire_responses_data) do
      [
        OpenStruct.new(id: 1, resource: OpenStruct.new(subject: reference)),
        OpenStruct.new(id: 2, resource: OpenStruct.new(subject: reference))
      ]
    end
    let(:formatted_hash) do
      {
        'I2-SLRRT64GFG' => [
          OpenStruct.new(id: 1, resource: OpenStruct.new(subject: reference)),
          OpenStruct.new(id: 2, resource: OpenStruct.new(subject: reference))
        ]
      }
    end

    before do
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id).and_return({})
      allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
    end

    it 'returns a hash' do
      expect(subject.manufacture(default_options.merge(questionnaire_responses: questionnaire_responses_data))
        .hashed_questionnaire_responses).to eq(formatted_hash)
    end
  end

  describe '#hashed_questionnaires' do
    let(:questionnaire_data) do
      [
        OpenStruct.new(
          id: 1,
          to_hash: { 'resource' => { 'useContext' => [{
            'valueCodeableConcept' => { 'coding' => [{ 'code' => 'vha_442_3049' }] }
          }] } }
        ),
        OpenStruct.new(
          id: 2,
          to_hash: { 'resource' => { 'useContext' => [{
            'valueCodeableConcept' => { 'coding' => [{ 'code' => 'vha_442_3049' }] }
          }] } }
        )
      ]
    end
    let(:formatted_hash) do
      {
        'vha_442_3049' => [
          OpenStruct.new(
            id: 1,
            to_hash: { 'resource' => { 'useContext' => [{
              'valueCodeableConcept' => { 'coding' => [{ 'code' => 'vha_442_3049' }] }
            }] } }
          ),
          OpenStruct.new(
            id: 2,
            to_hash: { 'resource' => { 'useContext' => [{
              'valueCodeableConcept' => { 'coding' => [{ 'code' => 'vha_442_3049' }] }
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
      expect(subject.manufacture(default_options.merge(questionnaires: questionnaire_data)).hashed_questionnaires)
        .to eq(formatted_hash)
    end
  end

  describe '#combine' do
    let(:appointments) do
      [
        double(
          'Appointments',
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
                           identifier: [double('first', value: 'vha_442'), double('last', value: 'vha_442_3049')],
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
          double('Questionnaire', resource: double('Resource', id: 'abc-123-def-455', title: 'Primary Care'))
        ]
      }
    end
    let(:base_questionnaire_manager) do
      {
        appointment: {
          id: 'I2-SLRRT64GFG'
        },
        organization: {
          id: 'vha_442'
        },
        location: {
          id: 'I2-LABC'
        }
      }
    end

    before do
      allow_any_instance_of(subject).to receive(:appointments).and_return(appointments)
      allow_any_instance_of(subject).to receive(:locations_with_id).and_return(hashed_locations)
      allow_any_instance_of(subject).to receive(:organizations_by_facility_ids).and_return(hashed_organizations)
      allow_any_instance_of(subject).to receive(:questionnaires_with_facility_clinic_id)
        .and_return(hashed_questionnaires)
    end

    context 'when no sip and no questionnaire response data' do
      let(:response) do
        {
          data: [
            base_questionnaire_manager.merge(
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: []
                }
              ]
            ).with_indifferent_access
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
      end

      it 'returns appointment with questionnaire and empty questionnaire response' do
        expect(subject.manufacture(default_options).combine).to eq(response)
      end
    end

    context 'when questionnaire response data and no sip' do
      let(:questionnaire_response_hash) do
        {
          'I2-SLRRT64GFG' => [
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
            base_questionnaire_manager.merge(
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: [
                    {
                      id: 'abc-123-def-455',
                      status: 'completed',
                      submitted_on: '2021-02-01'
                    }
                  ]
                }
              ]
            ).with_indifferent_access
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id)
          .and_return(questionnaire_response_hash)
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return({})
      end

      it 'returns appointment with questionnaire and matching questionnaire response' do
        expect(subject.manufacture(default_options).combine).to eq(response)
      end
    end

    context 'when sip and no questionnaire response data' do
      let(:sip_hash) do
        {
          'I2-SLRRT64GFG' => [
            double('SaveInProgress', form_id: 'HC-QSTNR_I2-SLRRT64GFG_abc-123-def-455')
          ]
        }
      end
      let(:response) do
        {
          data: [
            base_questionnaire_manager.merge(
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: [
                    {
                      form_id: 'HC-QSTNR_I2-SLRRT64GFG_abc-123-def-455',
                      status: 'in-progress'
                    }
                  ]
                }
              ]
            ).with_indifferent_access
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id).and_return({})
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return(sip_hash)
      end

      it 'returns appointment with questionnaire and matching questionnaire response' do
        expect(subject.manufacture(default_options).combine).to eq(response)
      end
    end

    context 'when questionnaire response and sip data' do
      let(:hashed_questionnaires) do
        {
          'vha_442_3049' => [
            double('Questionnaire', resource: double('Resource', id: 'abc-123-def-455', title: 'Primary Care')),
            double('Questionnaire', resource: double('Resource', id: 'ccc-123-ddd-455', title: 'Donut Intake'))
          ]
        }
      end
      let(:questionnaire_response_hash) do
        {
          'I2-SLRRT64GFG' => [
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
          'I2-SLRRT64GFG' => [
            double('SaveInProgress',
                   form_id: 'HC-QSTNR_I2-SLRRT64GFG_ccc-123-ddd-455')
          ]
        }
      end
      let(:response) do
        {
          data: [
            base_questionnaire_manager.merge(
              questionnaire: [
                {
                  id: 'abc-123-def-455',
                  title: 'Primary Care',
                  questionnaire_response: [
                    {
                      id: 'abc-123-def-455',
                      status: 'completed',
                      submitted_on: '2021-02-01'
                    }
                  ]
                },
                {
                  id: 'ccc-123-ddd-455',
                  title: 'Donut Intake',
                  questionnaire_response: [
                    {
                      form_id: 'HC-QSTNR_I2-SLRRT64GFG_ccc-123-ddd-455',
                      status: 'in-progress'
                    }
                  ]
                }
              ]
            ).with_indifferent_access
          ]
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:questionnaire_responses_with_appointment_id)
          .and_return(questionnaire_response_hash)
        allow_any_instance_of(subject).to receive(:sip_with_appointment_id).and_return(sip_hash)
      end

      it 'returns appointment with questionnaire and matching questionnaire response' do
        expect(subject.manufacture(default_options).combine).to eq(response)
      end
    end
  end
end
