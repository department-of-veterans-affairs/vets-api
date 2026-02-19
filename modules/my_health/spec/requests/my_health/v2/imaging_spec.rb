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

  describe 'GET /my_health/v2/medical_records/imaging/thumbnail_proxy' do
    let(:proxy_path) { '/my_health/v2/medical_records/imaging/thumbnail_proxy' }
    let(:valid_s3_url) do
      'https://mhv-sysb-cvix-thumbnails.s3.us-gov-west-1.amazonaws.com/hashed-abc123/thumb.jpg' \
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=1800&X-Amz-Signature=abc123'
    end
    let(:image_binary) { "\xFF\xD8\xFF\xE0".b + ('x' * 100) }

    context 'happy path' do
      it 'proxies the image from S3 and returns JPEG binary' do
        stub_request(:get, /mhv-sysb-cvix-thumbnails\.s3\.us-gov-west-1\.amazonaws\.com/)
          .to_return(status: 200, body: image_binary, headers: { 'Content-Type' => 'image/jpeg' })

        get proxy_path, params: { url: valid_s3_url }

        expect(response).to be_successful
        expect(response.headers['Content-Type']).to include('image/jpeg')
        expect(response.body.bytes).to eq(image_binary.bytes)
      end
    end

    context 'when url param is missing' do
      it 'returns a 400 error' do
        get proxy_path

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when URL host is not an allowed S3 domain' do
      it 'returns a 403 error for non-S3 hosts' do
        get proxy_path, params: { url: 'https://evil-site.com/malicious.jpg' }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('URL not allowed')
      end

      it 'returns a 403 error for non-HTTPS URLs' do
        get proxy_path, params: { url: 'http://mhv-sysb-cvix-thumbnails.s3.us-gov-west-1.amazonaws.com/thumb.jpg' }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when URL is malformed' do
      it 'returns a 400 error' do
        get proxy_path, params: { url: ':::not-a-url' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when S3 returns an error' do
      it 'returns a 502 bad gateway with error payload' do
        stub_request(:get, /mhv-sysb-cvix-thumbnails\.s3\.us-gov-west-1\.amazonaws\.com/)
          .to_return(status: 403, body: 'Access Denied')

        get proxy_path, params: { url: valid_s3_url }

        expect(response).to have_http_status(:bad_gateway)
        json = JSON.parse(response.body)
        expect(json).to have_key('errors')
      end
    end

    context 'when S3 host uses dash-style region format' do
      let(:dash_style_url) do
        'https://mhv-pr-cvix-thumbnails.s3-us-gov-west-1.amazonaws.com/thumb.jpg?X-Amz-Signature=abc'
      end

      it 'accepts the URL and proxies successfully' do
        stub_request(:get, /mhv-pr-cvix-thumbnails\.s3-us-gov-west-1\.amazonaws\.com/)
          .to_return(status: 200, body: image_binary, headers: { 'Content-Type' => 'image/jpeg' })

        get proxy_path, params: { url: dash_style_url }

        expect(response).to be_successful
        expect(response.headers['Content-Type']).to include('image/jpeg')
      end
    end

    context 'when S3 bucket name is not in the allowlist' do
      it 'returns a 403 error for unknown bucket names' do
        get proxy_path, params: {
          url: 'https://some-other-bucket.s3.us-gov-west-1.amazonaws.com/thumb.jpg'
        }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with each allowed environment bucket' do
      %w[di-5 intb sysb pr].each do |env|
        it "accepts mhv-#{env}-cvix-thumbnails bucket" do
          bucket_url = "https://mhv-#{env}-cvix-thumbnails.s3.us-gov-west-1.amazonaws.com/thumb.jpg?X-Amz-Signature=abc"
          stub_request(:get, /mhv-#{Regexp.escape(env)}-cvix-thumbnails/)
            .to_return(status: 200, body: image_binary, headers: { 'Content-Type' => 'image/jpeg' })

          get proxy_path, params: { url: bucket_url }

          expect(response).to be_successful
        end
      end
    end
  end
end
