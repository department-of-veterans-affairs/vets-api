# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'health_quest patients', type: :request do
  let(:access_denied_message) { 'You do not have access to the health quest service' }

  describe 'GET signed_in_patient response' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get '/health_quest/v0/signed_in_patient'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/signed_in_patient'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'resourceType' => 'Patient' } })
      end

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::Resource::Query).to receive(:get).with(anything).and_return(client_reply)
      end

      it 'returns a Patient FHIR response type' do
        get '/health_quest/v0/signed_in_patient'

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Patient' })
      end
    end
  end

  describe 'POST patient response' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        post '/health_quest/v0/patients'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        post '/health_quest/v0/patients'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'resourceType' => 'Patient' } })
      end

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::Resource::Query).to receive(:create)
          .with(anything, anything).and_return(client_reply)
      end

      it 'returns a Patient FHIR response type' do
        post '/health_quest/v0/patients'

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Patient' })
      end
    end
  end
end
