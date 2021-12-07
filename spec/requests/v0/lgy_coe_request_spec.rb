# frozen_string_literal: true

require 'rails_helper'

describe 'LGY API' do
  context 'when user is signed in' do
    let(:user) { create :user }

    before { sign_in_as user }

    describe 'GET v0/coe/status' do
      context 'when scenario is automatic approval' do
        it 'response code is 200' do
          lgy_service = double('LGY Service')
          allow_any_instance_of(V0::CoeController).to receive(:lgy_service) { lgy_service }
          expect(lgy_service).to receive(:get_determination_and_application).and_return 'automatic'
          get '/v0/coe/status'
          expect(response).to have_http_status(:ok)
        end

        it 'response is in JSON format' do
          lgy_service = double('LGY Service')
          allow_any_instance_of(V0::CoeController).to receive(:lgy_service) { lgy_service }
          expect(lgy_service).to receive(:get_determination_and_application).and_return 'automatic'
          get '/v0/coe/status'
          expect(response.content_type).to eq('application/json; charset=utf-8')
        end

        it 'response status key is eligible' do
          lgy_service = double('LGY Service')
          allow_any_instance_of(V0::CoeController).to receive(:lgy_service) { lgy_service }
          expect(lgy_service).to receive(:get_determination_and_application).and_return 'automatic'
          get '/v0/coe/status'

          json_body = JSON.parse(response.body, object_class: OpenStruct)
          expect(json_body.status).to eq 'automatic'
        end
      end
    end
  end
end
