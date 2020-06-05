# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appointment', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/vaos/v1/Appointment'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :vaos) }

    describe 'GET /vaos/v1/Appointment?queries' do
      context 'with a multi param query' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'appointment', 'search_200.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        let(:query_string) do
          'patient:Patient.identifier=1012845331V153043&date=ge2020-05-01T07:00:00Z' \
            '&date=lt2020-08-31T17:00:00Z&_include=Appointment:location'
        end

        it 'returns a 200 and passes the body through' do
          VCR.use_cassette('vaos/fhir/appointment/search_200', match_requests_on: %i[method uri]) do
            get "/vaos/v1/Appointment?#{query_string}"

            expect(response).to have_http_status(:ok)
            expect(response.body).to eq(expected_body)
          end
        end
      end

      context 'with a multi param query that returns no records' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'appointment', 'search_no_records.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        let(:query_string) do
          'patient:Patient.identifier=1012845331V153043&date=ge2010-05-01T07:00:00Z' \
            '&date=lt2010-08-31T17:00:00Z&_include=Appointment:location'
        end

        it 'returns a 200 and passes the body through' do
          VCR.use_cassette('vaos/fhir/appointment/search_no_records', match_requests_on: %i[method uri]) do
            get "/vaos/v1/Appointment?#{query_string}"

            expect(response).to have_http_status(:ok)
            expect(response.body).to eq(expected_body)
          end
        end
      end
    end
  end
end
