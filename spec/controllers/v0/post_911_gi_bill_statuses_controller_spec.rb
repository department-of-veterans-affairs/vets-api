# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::Post911GIBillStatusesController, type: :controller do
  include SchemaMatchers

  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  context 'with a mocked gi bill status response' do
    let(:mock_response) do
      YAML.load_file(
        Rails.root.join('config', 'evss', 'mock_gi_bill_status_response.yml.example')
      )
    end

    before do
      Settings.evss.mock_gi_bill_status = true
      allow_any_instance_of(EVSS::GiBillStatus::MockService).to receive(:mocked_response).and_return(mock_response)
    end

    it 'should have a response that matches the schema' do
      request.headers['Authorization'] = "Token token=#{session.token}"
      get :show
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('post911_gi_bill_status', strict: false)
    end
  end

  context 'without mock responses' do
    before { Settings.evss.mock_gi_bill_status = false }
    describe 'when EVSS has no knowledge of user' do
      it 'responds with 404' do
        # generated IN EVSS CI with user ssn=796066619
        VCR.use_cassette('evss/gi_bill_status/vet_not_found') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
          expect(response).to have_http_status(:not_found)
        end
      end
    end
    describe 'when EVSS has no info of user' do
      it 'renders nil data' do
        VCR.use_cassette('evss/gi_bill_status/vet_with_no_info') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
          json = JSON.parse(response.body)
          expect(response).to have_http_status(:ok)
          expect(json['data']).to be_nil
        end
      end
      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/Unexpected response from EVSS GiBillStatus/)
        VCR.use_cassette('evss/gi_bill_status/vet_with_no_info') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
        end
      end
    end
  end
end
