# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/vaos/v1/organization/353830'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :vaos) }

    describe 'GET /vaos/v0/organization/:id' do
      context 'with a valid read Organization response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/fhir/read_organization_200', match_requests_on: %i[method uri]) do
            expect { get '/vaos/v1/organization/353830' }
              .to trigger_statsd_increment('api.vaos.fhir.read.organization.total', times: 1, value: 1)

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'with a 404 response' do
        it 'returns a 404 operation outcome' do
          VCR.use_cassette('vaos/fhir/read_organization_404', match_requests_on: %i[method uri]) do
            get '/vaos/v1/organization/353000'

            expect(response).to have_http_status(:not_found)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_404')
          end
        end
      end

      context 'with a 500 response' do
        it 'returns a 502 operation outcome' do
          VCR.use_cassette('vaos/fhir/read_organization_500', match_requests_on: %i[method uri]) do
            get '/vaos/v1/organization/1234567'

            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_502')
          end
        end
      end
    end
  end
end
