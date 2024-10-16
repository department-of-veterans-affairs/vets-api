# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HealthQuest::V0::Organizations', type: :request do
  let(:access_denied_message) { 'You do not have access to the health quest service' }

  describe 'GET organizations `index`' do
    context 'loa1 user' do
      let(:current_user) { build(:user, :loa1) }

      before do
        sign_in_as(current_user)
      end

      it 'has forbidden status' do
        get '/health_quest/v0/organizations?_id=1234'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/organizations?_id=1234'

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

      it 'returns a FHIR Bundle' do
        get '/health_quest/v0/organizations?_id=abc123,def456'

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Bundle' })
      end
    end
  end

  describe 'GET organization `show`' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get '/health_quest/v0/organizations/I2-ABC123'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/organizations/I2-ABC123'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'resourceType' => 'Location' } })
      end

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::Resource::Query).to receive(:get).with(anything).and_return(client_reply)
      end

      it 'returns a FHIR type of Location' do
        get '/health_quest/v0/organizations/I2-ABC123'

        expect(JSON.parse(response.body)).to eq({ 'resourceType' => 'Location' })
      end
    end
  end
end
