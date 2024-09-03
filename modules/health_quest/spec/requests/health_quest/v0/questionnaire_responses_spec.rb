# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HealthQuest::V0::QuestionnaireResponses', type: :request do
  let(:access_denied_message) { 'You do not have access to the health quest service' }
  let(:questionnaire_responses_id) { '32' }

  describe 'GET questionnaire response' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get "/health_quest/v0/questionnaire_responses/#{questionnaire_responses_id}"

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get "/health_quest/v0/questionnaire_responses/#{questionnaire_responses_id}"

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:id) { 'faae134c-9c7b-49d7-8161-10e314da4de1' }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'resourceType' => 'QuestionnaireResponse' } })
      end

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::Resource::Query).to receive(:get).with(anything).and_return(client_reply)
      end

      it 'returns a FHIR type of QuestionnaireResponse' do
        get "/health_quest/v0/questionnaire_responses/#{id}"

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'QuestionnaireResponse' })
      end
    end
  end

  describe 'GET all questionnaire responses' do
    context 'loa1 user' do
      let(:current_user) { build(:user, :loa1) }

      before do
        sign_in_as(current_user)
      end

      it 'has forbidden status' do
        get '/health_quest/v0/questionnaire_responses'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/questionnaire_responses'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) { double('FHIR::ClientReply', response: { body: { 'resourceType' => 'Bundle' } }) }

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::Resource::Query).to receive(:search).with(anything).and_return(client_reply)
      end

      it 'returns a FHIR bundle' do
        get '/health_quest/v0/questionnaire_responses?patient=123dfgh'

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Bundle' })
      end
    end
  end

  describe 'POST questionnaire response' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        post '/health_quest/v0/questionnaire_responses'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        post '/health_quest/v0/questionnaire_responses'

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
        post '/health_quest/v0/questionnaire_responses', params: { questionnaire_response: data }

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'QuestionnaireResponse' })
      end
    end
  end
end
