# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'Appointments', type: :request do
  include SchemaMatchers
  include ErrorDetails

  before do
    allow_any_instance_of(User).to receive(:icn).and_return('1234')
    sign_in
  end

  describe 'GET /v0/appointments' do
    context 'with a 200 response' do
      it 'should match the appointments schema' do
        VCR.use_cassette('ihub/appointments/success') do
          get '/v0/appointments'

          expect(response).to have_http_status(:ok)
          # expect(response).to match_response_schema('appointments_response')
        end
      end
    end

    context 'the user does not have an ICN' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return(nil)
      end

      it 'should match the errors schema', :aggregate_failures do
        get '/v0/appointments'

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_response_schema('errors')
      end
    end

    context 'when iHub experiences an error' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('ihub/appointments/error_occurred') do
          get '/v0/appointments'

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end
end
