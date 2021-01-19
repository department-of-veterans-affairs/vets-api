# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'health_quest questionnaires', type: :request do
  let(:access_denied_message) { 'You do not have access to the health quest service' }
  let(:questionnaires_id) { '32' }

  describe 'GET questionnaire' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get "/health_quest/v0/questionnaires/#{questionnaires_id}"

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get "/health_quest/v0/questionnaires/#{questionnaires_id}"

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:headers) { { 'Accept' => 'application/json+fhir' } }
      let(:id) { 'faae134c-9c7b-49d7-8161-10e314da4de1' }
      let(:session_service) { double('HealthQuest::SessionService', user: current_user, headers: headers) }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'resourceType' => 'Questionnaire' } })
      end

      before do
        sign_in_as(current_user)
        allow(HealthQuest::SessionService).to receive(:new).with(anything).and_return(session_service)
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Questionnaire::MapQuery)
          .to receive(:get).with(anything).and_return(client_reply)
      end

      it 'returns a FHIR type of Questionnaire' do
        get "/health_quest/v0/questionnaires/#{id}"

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Questionnaire' })
      end
    end
  end

  describe 'GET all questionnaires' do
    context 'loa1 user' do
      let(:current_user) { build(:user, :loa1) }

      before do
        sign_in_as(current_user)
      end

      it 'has forbidden status' do
        get '/health_quest/v0/questionnaires'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/questionnaires'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:headers) { { 'Accept' => 'application/json+fhir' } }
      let(:session_service) { double('HealthQuest::SessionService', user: current_user, headers: headers) }
      let(:client_reply) { double('FHIR::ClientReply', response: { body: { 'resourceType' => 'Bundle' } }) }

      before do
        sign_in_as(current_user)
        allow(HealthQuest::SessionService).to receive(:new).with(anything).and_return(session_service)
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Questionnaire::MapQuery)
          .to receive(:search).with(anything).and_return(client_reply)
      end

      it 'returns a FHIR bundle' do
        get '/health_quest/v0/questionnaires'

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Bundle' })
      end
    end
  end
end
