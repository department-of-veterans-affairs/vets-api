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
      get '/vaos/v1/Organization/353830'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :vaos) }

    describe 'GET /vaos/v1/Organization/:id' do
      context 'with a valid read Organization response' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'read_organization_200.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        it 'returns a 200 and passes through the body' do
          VCR.use_cassette('vaos/fhir/read_organization_200', match_requests_on: %i[method uri]) do
            expect { get '/vaos/v1/Organization/353830' }
              .to trigger_statsd_increment('api.vaos.fhir.read.organization.total', times: 1, value: 1)

            expect(response).to have_http_status(:ok)
            expect(response.body).to eq(expected_body)
          end
        end
      end

      context 'with a 404 response' do
        it 'returns a 404 operation outcome' do
          VCR.use_cassette('vaos/fhir/read_organization_404', match_requests_on: %i[method uri]) do
            get '/vaos/v1/Organization/353000'

            expect(response).to have_http_status(:not_found)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_404')
          end
        end
      end

      context 'with a 500 response' do
        it 'returns a 502 operation outcome' do
          VCR.use_cassette('vaos/fhir/read_organization_500', match_requests_on: %i[method uri]) do
            get '/vaos/v1/Organization/1234567'

            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_502')
          end
        end
      end
    end

    describe 'GET /vaos/v1/Organization?queries' do
      context 'when records are found' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'search_organization_200.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        let(:query_string) { '?identifier=983,984' }

        it 'returns a 200' do
          VCR.use_cassette('vaos/fhir/search_organization_200.yml', match_requests_on: %i[method uri]) do
            # expect { get "/vaos/v1/Organization#{query_string}" }
            #  .to trigger_statsd_increment('api.vaos.fhir.search.healthcare_service.total', times: 1, value: 1)
            get "/vaos/v1/Organization#{query_string}"
            expect(response).to have_http_status(:not_found)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_404')
          end
        end
      end

      context 'when records are not found' do
        let(:query_string) { '?identifier=101' }

        xit 'returns a 404' do
          VCR.use_cassette('vaos/fhir/search_organization_404.yml', match_requests_on: %i[method uri]) do
            get "/vaos/v1/Organization#{query_string}"

            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context 'when a backend service exception occurs' do
        let(:query_string) { '?identifier=983,101' }

        xit 'returns a 502' do
          VCR.use_cassette('vaos/fhir/search_organization_404.yml', match_requests_on: %i[method uri]) do
            get "/vaos/v1/Organization#{query_string}"

            expect(response).to have_http_status(:bad_gateway)
          end
        end
      end
    end
  end
end
