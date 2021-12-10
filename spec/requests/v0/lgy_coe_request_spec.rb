# frozen_string_literal: true

require 'rails_helper'

describe 'LGY API' do
  context 'when user is signed in' do
    let(:user) { create(:evss_user, :loa3) }

    before { sign_in_as user }

    describe 'GET v0/coe/status' do
      context 'when determination is eligible and application is 404' do
        it 'response code is 200' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              get '/v0/coe/status'
              expect(response).to have_http_status(:ok)
            end
          end
        end

        it 'response is in JSON format' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              get '/v0/coe/status'
              expect(response.content_type).to eq('application/json; charset=utf-8')
            end
          end
        end

        it 'response status key is eligible' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              get '/v0/coe/status'
              json_body = JSON.parse(response.body)
              expect(json_body['data']['attributes']).to eq 'status' => 'eligible'
            end
          end
        end
      end
    end
  end
end
