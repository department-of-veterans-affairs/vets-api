# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V1::Location', skip: 'deprecated', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '/vaos/v1/Location' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v1/Location/393833'
        expect(response).to have_http_status(:forbidden)
        error_object = JSON.parse(response.body)
        expect(error_object['resourceType']).to eq('Location')
        expect(error_object['issue'].first['details']['text'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :vaos) }

      context 'FHIR Location Resource by ID'
      context 'a valid response' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'location', 'read_by_id_200.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        it 'returns a 200 returning Location resource corresponding to id' do
          VCR.use_cassette('vaos/fhir/location/read_by_id_200', match_requests_on: %i[method path query]) do
            expect { get '/vaos/v1/Location/393833' }
              .to trigger_statsd_increment('api.vaos.fhir.read.location.total', times: 1, value: 1)

            expect(response).to have_http_status(:success)
            expect(response.body).to eq(expected_body)
          end
        end
      end

      context 'with a 404 response' do
        it 'returns a 404 operation outcome' do
          VCR.use_cassette('vaos/fhir/location/read_by_id_404', match_requests_on: %i[method path query]) do
            get '/vaos/v1/Location/353000'

            expect(response).to have_http_status(:not_found)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_404')
          end
        end
      end
    end
  end
end
