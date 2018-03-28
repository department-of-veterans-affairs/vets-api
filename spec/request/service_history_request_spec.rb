# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'service_history', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/profile/service_history' do
    context 'with a 200 response' do
      context 'with one military service episode' do
        it 'should match the service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid') do
            get '/v0/profile/service_history', nil, auth_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('service_history_response')
          end
        end
      end

      context 'with multiple military service episodes' do
        it 'should match the service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
            get '/v0/profile/service_history', nil, auth_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('service_history_response')
          end
        end
      end
    end
  end
end
