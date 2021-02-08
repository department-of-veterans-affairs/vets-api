# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'health_quest questionnaire_manager', type: :request do
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
      let(:id) { 'faae134c-9c7b-49d7-8161-10e314da4de1' }
      let(:session_store) { double('SessionStore', token: '123abc') }
      let(:client_reply) do
        double('FHIR::ClientReply', response: { body: { 'data' => [] } }, resource: default_client_reply)
      end
      let(:questionnaire_client_reply) do
        double('FHIR::ClientReply', resource: double('FHIR::ClientReply', entry: [{}]))
      end
      let(:appointments) { { data: [{}, {}] } }

      before do
        sign_in_as(current_user)
        allow_any_instance_of(HealthQuest::Lighthouse::Session).to receive(:retrieve).and_return(session_store)
        allow_any_instance_of(HealthQuest::QuestionnaireManager::Transformer)
          .to receive(:get_use_context).with(anything).and_return('venue$583/12345')
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Patient::MapQuery)
          .to receive(:get).with(anything).and_return(client_reply)
        allow_any_instance_of(HealthQuest::PatientGeneratedData::Questionnaire::MapQuery)
          .to receive(:search).with(anything).and_return(questionnaire_client_reply)
        allow_any_instance_of(HealthQuest::AppointmentService)
          .to receive(:get_appointments).with(anything, anything).and_return(appointments)
      end

      it 'returns a WIP response' do
        get '/health_quest/v0/questionnaire_manager'

        expect(JSON.parse(response.body)).to eq({ 'data' => 'WIP' })
      end
    end
  end
end
