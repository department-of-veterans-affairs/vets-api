# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/imaging_service'

RSpec.describe 'MyHealth::V2::ImagingController', :skip_json_api_validation, type: :request do
  let(:path) { '/my_health/v2/medical_records/imaging' }
  let(:default_params) { { start_date: '2024-01-01', end_date: '2025-05-31' } }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/imaging' do
    context 'happy path' do
      it 'returns a successful response' do
        VCR.use_cassette('unified_health_data/get_imaging_studies_200', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first['type']).to eq('imaging_study')
        expect(json_response.first).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response.first['attributes']).to include(
          'id',
          'status',
          'date',
          'description'
        )
      end

      it 'returns a successful response with an empty array' do
        VCR.use_cassette('unified_health_data/get_imaging_studies_no_records', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::ImagingService).to receive(:get_imaging_studies)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        VCR.use_cassette('unified_health_data/get_imaging_studies_200', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::ImagingService).to receive(:get_imaging_studies)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        VCR.use_cassette('unified_health_data/get_imaging_studies_200', match_requests_on: %i[method path]) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end

  describe 'GET /my_health/v2/medical_records/imaging/:id/thumbnails' do
    let(:record_id) { 'urn-vastudy-200CRNR-CM-6-ezJjLWI2LWQwLWVkLWE0LTQ0LTQwLWVlLWI0LWR' }
    let(:thumbnails_path) { "/my_health/v2/medical_records/imaging/#{record_id}/thumbnails" }
    let(:thumbnails_params) { { start_date: '2026-01-01', end_date: '2027-01-01' } }

    context 'happy path' do
      it 'returns a successful response with imaging study data' do
        VCR.use_cassette('unified_health_data/get_imaging_study_200', match_requests_on: %i[method path]) do
          get thumbnails_path, headers: { 'X-Key-Inflection' => 'camel' }, params: thumbnails_params
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first['type']).to eq('imaging_study')
        expect(json_response.first).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response.first['attributes']).to include(
          'id',
          'status',
          'date',
          'description',
          'series'
        )

        # Verify the presigned thumbnail URL makes it through to the response
        series = json_response.first['attributes']['series']
        expect(series).to be_an(Array)
        expect(series.first['instances']).to be_an(Array)
        instance = series.first['instances'].first
        expect(instance['thumbnailUrl']).to start_with('https://test-cvix-thumbnails.s3.us-gov-west-1.amazonaws.com/')
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::ImagingService).to receive(:get_imaging_study)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        VCR.use_cassette('unified_health_data/get_imaging_study_200', match_requests_on: %i[method path]) do
          get thumbnails_path, headers: { 'X-Key-Inflection' => 'camel' }, params: thumbnails_params
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::ImagingService).to receive(:get_imaging_study)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        VCR.use_cassette('unified_health_data/get_imaging_study_200', match_requests_on: %i[method path]) do
          get thumbnails_path, headers: { 'X-Key-Inflection' => 'camel' }, params: thumbnails_params
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end

  describe 'GET /my_health/v2/medical_records/imaging/:id/dicom' do
    let(:record_id) { 'urn-vastudy-200CRNR-CM-4-ezA1LTQ4LTc5LTQxLWQ5LTc5LTRjLWMxLWJjLTJ' }
    let(:dicom_path) { "/my_health/v2/medical_records/imaging/#{record_id}/dicom" }
    let(:dicom_params) { { start_date: '2026-01-01', end_date: '2027-01-01' } }

    context 'happy path' do
      it 'returns a successful response with DICOM zip URL' do
        VCR.use_cassette('unified_health_data/get_dicom_zip_200', match_requests_on: %i[method path]) do
          get dicom_path, headers: { 'X-Key-Inflection' => 'camel' }, params: dicom_params
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first['type']).to eq('imaging_study')
        expect(json_response.first['attributes']).to include(
          'id',
          'status',
          'date',
          'description'
        )

        # Verify the presigned DICOM zip URL makes it through to the response
        expect(json_response.first['attributes']['dicomZipUrl']).to start_with(
          'https://test-cvix-zips.s3.us-gov-west-1.amazonaws.com/'
        )
      end
    end

    context 'error responses' do
      it 'returns a 500 response when there is a server error' do
        allow_any_instance_of(UnifiedHealthData::ImagingService).to receive(:get_dicom_zip)
          .and_raise(Common::Exceptions::InternalServerError.new(Faraday::ServerError.new))
        VCR.use_cassette('unified_health_data/get_dicom_zip_200', match_requests_on: %i[method path]) do
          get dicom_path, headers: { 'X-Key-Inflection' => 'camel' }, params: dicom_params
        end
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error response when there is a client error' do
        allow_any_instance_of(UnifiedHealthData::ImagingService).to receive(:get_dicom_zip)
          .and_raise(Common::Client::Errors::ClientError.new(Faraday::ClientError.new))
        VCR.use_cassette('unified_health_data/get_dicom_zip_200', match_requests_on: %i[method path]) do
          get dicom_path, headers: { 'X-Key-Inflection' => 'camel' }, params: dicom_params
        end
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
