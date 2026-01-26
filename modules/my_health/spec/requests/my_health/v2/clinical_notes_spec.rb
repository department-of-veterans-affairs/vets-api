# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'MyHealth::V2::ClinicalNotesController', :skip_json_api_validation, type: :request do
  let(:user_id) { '11898795' }
  let(:default_params) { { start_date: '2024-01-01', end_date: '2025-05-31' } }
  let(:path) { '/my_health/v2/medical_records/clinical_notes' }

  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }
  let(:notes_flipper) { :mhv_accelerated_delivery_care_notes_enabled }

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv) }

  before do
    Timecop.freeze('2025-06-02T08:00:00Z')
    sign_in_as(current_user)
    allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(notes_flipper, instance_of(User)).and_return(true)
  end

  after do
    Timecop.return
  end

  describe 'GET /my_health/v2/medical_records/notes#index' do
    context 'happy path' do
      it 'returns a successful response' do
        allow(UniqueUserEvents).to receive(:log_events)
        VCR.use_cassette('unified_health_data/get_clinical_notes_200', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' },
              params: default_params
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data'].count).to eq(2)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].first['type']).to eq('clinical_note')
        expect(json_response['data'].first).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response['data'].first['attributes']).to include(
          'id',
          'name',
          'noteType',
          'loincCodes',
          'date',
          'dateSigned',
          'writtenBy',
          'signedBy',
          'admissionDate',
          'dischargeDate',
          'location',
          'note'
        )

        # Verify event logging was called
        expect(UniqueUserEvents).to have_received(:log_events).with(
          user: anything,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_NOTES_ACCESSED
          ]
        )
      end

      it 'returns a successful response with an empty data array' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_no_records', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' },
              params: default_params
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to eq([])
      end

      it 'returns a successful response without date parameters (backward compatibility)' do
        allow(UniqueUserEvents).to receive(:log_events)
        VCR.use_cassette('unified_health_data/get_clinical_notes_200', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data'].count).to eq(2)
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_care_summaries_and_notes)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' },
              params: default_params
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_care_summaries_and_notes)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' },
              params: default_params
        end
        expect(response).to have_http_status(:bad_gateway)
      end

      it 'returns an error when start_date is invalid' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' },
              params: { start_date: 'invalid-date', end_date: '2025-05-31' }
        end
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['detail']).to include("Invalid start_date: 'invalid-date'")
      end

      it 'returns an error when end_date is invalid' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' },
              params: { start_date: '2024-01-01', end_date: 'bad-format' }
        end
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['detail']).to include("Invalid end_date: 'bad-format'")
      end
    end
  end

  describe 'GET /my_health/v2/medical_records/notes#show' do
    context 'happy path' do
      it 'returns a successful response for a single note' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_200', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/clinical_notes/15249697279', headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data']['type']).to eq('clinical_note')
        expect(json_response['data']).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response['data']['attributes']).to include(
          'id',
          'name',
          'noteType',
          'loincCodes',
          'date',
          'dateSigned',
          'writtenBy',
          'signedBy',
          'admissionDate',
          'dischargeDate',
          'location',
          'note'
        )
      end

      # TODO: Probably this should return a 404? Maybe?
      it 'returns a 404 not found' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_no_records', match_requests_on: %i[method path]) do
          get '/my_health/v2/medical_records/clinical_notes/12345',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_summary_or_note)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes/12345',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_summary_or_note)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        # This cassette doesn't matter since we're stubbing the service call to raise an error
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes/12345',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
