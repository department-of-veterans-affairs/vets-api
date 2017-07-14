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

    context 'when EVSS response is 500' do
      before do
        allow_any_instance_of(EVSS::GiBillStatus::GiBillStatusResponse).to receive(:status).and_return(500)
      end

      it 'should respond with 200 & SERVER_ERROR meta' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        get :show
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['status']).to eq('SERVER_ERROR')
      end
    end

    context 'when EVSS response is 403' do
      before do
        allow_any_instance_of(EVSS::GiBillStatus::GiBillStatusResponse).to receive(:status).and_return(403)
      end

      it 'should respond with 200 & NOT_AUTHORIZED meta' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        get :show
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['status']).to eq('NOT_AUTHORIZED')
      end
    end
  end

  context 'without mock responses' do
    # must be connected to EVSS openvpn to re-generate VCR
    before { Settings.evss.mock_gi_bill_status = false }

    describe 'when EVSS has no knowledge of user' do
      # special EVSS CI user ssn=796066619
      let(:user) { FactoryGirl.create(:loa3_user, ssn: '796066619', uuid: 'ertydfh456') }
      let(:session) { Session.create(uuid: user.uuid) }
      it 'responds with 404' do
        VCR.use_cassette('evss/gi_bill_status/vet_not_found') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
          expect(response).to have_http_status(:not_found)
        end
      end
    end
    describe 'when EVSS has no info of user' do
      # special EVSS CI user ssn=796066619
      let(:user) { FactoryGirl.create(:loa3_user, ssn: '796066622', uuid: 'fghj3456') }
      let(:session) { Session.create(uuid: user.uuid) }
      it 'renders nil data' do
        VCR.use_cassette('evss/gi_bill_status/vet_with_no_info') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
