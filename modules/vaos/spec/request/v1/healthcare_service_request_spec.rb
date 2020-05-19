# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V1::HeathcareService', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '/vaos/v1/HealthcareService' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v1/HealthcareService'
        expect(response).to have_http_status(:forbidden)
        error_object = JSON.parse(response.body)
        expect(error_object['resourceType']).to eq('Healthcare_service')
        expect(error_object['issue'].first['details']['text'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :vaos) }

      context 'FHIR HealthcareService Resource search' do
        context 'a valid response' do
          let(:expected_body) do
            YAML.load_file(
              Rails.root.join(
                'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'healthcare_service', 'seearch_200.yml'
              )
            )['http_interactions'].first.dig('response', 'body', 'string')
          end

          let(:query_string) { '?organization.identifier=983&_include=HealthcareService%3Alocation' }

          it 'returns a 200 returning Location resource corresponding to id' do
            VCR.use_cassette('vaos/fhir/healthcare_service/read_by_id_200', record: :new_episodes) do
              expect { get "/vaos/v1/HealthcareService#{query_string}" }
                .to trigger_statsd_increment('api.vaos.fhir.read.healthcare_service.total', times: 1, value: 1)

              expect(response).to have_http_status(:success)
              expect(response.body).to eq(expected_body)
            end
          end
        end

        context 'with an invalid response' do
          it 'returns a X operation outcome' do
            VCR.use_cassette('vaos/fhir/location/search_X', record: :new_episodes) do
              get '/vaos/v1/HealthcareService?broken_query'

              binding.pry
              expect(response).to have_http_status(:not_found)
              expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_404')
            end
          end
        end
      end
    end
  end
end
