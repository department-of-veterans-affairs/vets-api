# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HealthQuest::V0::QuestionnaireManager', type: :request do
  let(:access_denied_message) { 'You do not have access to the health quest service' }
  let(:questionnaires_id) { '32' }
  let(:default_client_reply) { double('FHIR::ClientReply') }

  describe 'GET questionnaire_manager' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get '/health_quest/v0/questionnaire_manager'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/questionnaire_manager'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:questionnaire_manager_data) do
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
      let(:output) do
        {
          'data' => [
            {
              'appointment' => {
                'id' => 'I2-SLRRT64GFGJAJGX62Q55NSQV44VEE4ZBB7U7YZQVVGKJGQ4653IQ0000',
                'attributes' => {
                  'facility_id' => '534',
                  'clinic_id' => '12975'
                }
              },
              'questionnaire' => [
                {
                  'id' => 'abc-123-def-455',
                  'title' => 'Primary Care',
                  'questionnaire_response' => {
                    'id' => 'abc-123-def-455',
                    'status' => 'completed',
                    'submitted_on' => '2021-02-01'
                  }
                },
                {
                  'id' => 'ccc-123-ddd-455',
                  'title' => 'Donut Intake',
                  'questionnaire_response' => {
                    'status' => 'in-progress'
                  }
                }
              ]
            }
          ]
        }
      end

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::QuestionnaireManager::Factory).to receive(:all)
          .and_return(questionnaire_manager_data)
      end

      it 'returns a formatted hash response' do
        get '/health_quest/v0/questionnaire_manager'

        expect(JSON.parse(response.body)).to eq(output)
      end
    end
  end

  describe 'POST questionnaire manager' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        post '/health_quest/v0/questionnaire_manager'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        post '/health_quest/v0/questionnaire_manager'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'resourceType' => 'QuestionnaireResponse' } })
      end
      let(:data) do
        {
          appointment: { id: 'abc123' },
          questionnaire: { id: '123-abc-345-def', title: 'test' },
          item: []
        }
      end

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::Resource::Query).to receive(:create)
          .with(anything, anything).and_return(client_reply)
      end

      it 'returns a QuestionnaireResponse FHIR response type' do
        post '/health_quest/v0/questionnaire_manager', params: { questionnaireResponse: data }

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'QuestionnaireResponse' })
      end
    end
  end

  describe 'GET questionnaire_manager#show' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get '/health_quest/v0/questionnaire_manager/123-1bc'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/questionnaire_manager/123-1bc'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:questionnaire_response_id) { '123-1bc' }

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::QuestionnaireManager::Factory)
          .to receive(:generate_questionnaire_response_pdf).with(anything).and_return(questionnaire_response_id)
      end

      it 'returns the questionnaire_response_id for now' do
        get '/health_quest/v0/questionnaire_manager/123-1bc'

        expect(response.body).to eq('123-1bc')
      end

      it 'returns the questionnaire_response type' do
        get '/health_quest/v0/questionnaire_manager/123-1bc'

        expect(response.headers['Content-Type']).to eq('application/pdf')
      end

      it 'returns the questionnaire_response disposition' do
        content_disposition =
          "inline; filename=\"questionnaire_response.pdf\"; filename*=UTF-8''questionnaire_response.pdf"

        get '/health_quest/v0/questionnaire_manager/123-1bc'

        expect(response.headers['Content-Disposition']).to eq(content_disposition)
      end
    end
  end
end
