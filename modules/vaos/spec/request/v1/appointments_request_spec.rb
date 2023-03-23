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

        it 'returns HTTP status 200 and passes the body through' do
          VCR.use_cassette('vaos/fhir/appointment/search_200', match_requests_on: %i[method path query]) do
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

        it 'returns HTTP status 200 and passes the body through' do
          VCR.use_cassette('vaos/fhir/appointment/search_no_records', match_requests_on: %i[method path query]) do
            get "/vaos/v1/Appointment?#{query_string}"

            expect(response).to have_http_status(:ok)
            expect(response.body).to eq(expected_body)
          end
        end
      end
    end

    describe 'POST /vaos/v1/Appointment' do
      context 'with flipper disabled' do
        it 'returns HTTP status 403, forbidden' do
          Flipper.disable('va_online_scheduling')
          post '/vaos/v1/Appointment'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'with valid appointment' do
        let(:request_body) { File.read('spec/fixtures/fhir/dstu2/appointment_create.yml') }

        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'appointment',
              'post_appointment_create_request_201.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        it 'returns HTTP status 201, Created, and the new resource content in body' do
          VCR.use_cassette('vaos/fhir/appointment/post_appointment_create_request_201',
                           match_requests_on: %i[method path query]) do
            headers = { 'Content-Type' => 'application/json+fhir', 'Accept' => 'application/json+fhir' }
            post('/vaos/v1/Appointment', params: request_body, headers:)
            expect(response).to have_http_status(:created)
            expect(response.body).to eq(expected_body)
          end
        end
      end

      context 'with invalid appointment' do
        let(:invalid_request_body) { File.read('spec/fixtures/fhir/dstu2/invalid_appointment_create.yml') }

        it 'returns HTTP status 400, bad request' do
          VCR.use_cassette('vaos/fhir/appointment/post_appointment_invalid_request_400',
                           match_requests_on: %i[method path query]) do
            headers = { 'Content-Type' => 'application/json+fhir', 'Accept' => 'application/json+fhir' }
            post('/vaos/v1/Appointment', params: invalid_request_body, headers:)
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_400')
          end
        end
      end
    end

    describe 'PUT /vaos/v1/Appointment/id' do
      let(:request_body) { File.read('spec/fixtures/fhir/dstu2/appointment_update.yml') }

      context 'with flipper disabled' do
        it 'returns HTTP status 403, forbidden' do
          Flipper.disable('va_online_scheduling')
          put '/vaos/v1/Appointment/12345'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'with valid Appointment update' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'appointment',
              'put_appointment_request_200.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        it 'returns HTTP status 200 along with the updated resource' do
          VCR.use_cassette('vaos/fhir/appointment/put_appointment_request_200',
                           match_requests_on: %i[method path query]) do
            headers = { 'Content-Type' => 'application/json+fhir', 'Accept' => 'application/json+fhir' }
            put('/vaos/v1/Appointment/1631', params: request_body, headers:)
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(JSON.parse(expected_body))
          end
        end
      end

      context 'with invalid appointment update' do
        it 'returns HTTP status 400' do
          VCR.use_cassette('vaos/fhir/appointment/put_appointment_invalid_request_400',
                           match_requests_on: %i[method path query]) do
            headers = { 'Content-Type' => 'application/json+fhir', 'Accept' => 'application/json+fhir' }
            put('/vaos/v1/Appointment/1631X', params: request_body, headers:)
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_400')
          end
        end
      end

      context 'with appointment cancel request' do
        let(:request_body) { File.read('spec/fixtures/fhir/dstu2/appointment_cancel_update.yml') }

        it 'returns HTTP status 200 along with the cancelled resource' do
          VCR.use_cassette('vaos/fhir/appointment/put_appointment_cancel_request_200',
                           match_requests_on: %i[method path query]) do
            headers = { 'Content-Type' => 'application/json+fhir', 'Accept' => 'application/json+fhir' }
            put('/vaos/v1/Appointment/1631', params: request_body, headers:)
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['status']).to eq('cancelled')
          end
        end
      end
    end
  end
end
