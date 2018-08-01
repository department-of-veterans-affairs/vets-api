# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'Appointments', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    allow_any_instance_of(User).to receive(:icn).and_return('1234')
  end

  describe 'GET /v0/appointments' do
    context 'with a 200 response' do
      it 'should match the appointments schema' do
        VCR.use_cassette('ihub/appointments/success') do
          get '/v0/appointments', nil, auth_header

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('appointments_response')
        end
      end
    end

    context 'the user does not have an ICN' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return(nil)
      end

      it 'should match the errors schema', :aggregate_failures do
        get '/v0/appointments', nil, auth_header

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_response_schema('errors')
      end
    end

    context 'when iHub experiences an error' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('ihub/appointments/error_occurred') do
          get '/v0/appointments', nil, auth_header

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end
end
