# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/payload_manager'
require_relative '../../support/vba_document_fixtures'
require 'vba_documents/document_request_validator'
require 'vba_documents/multipart_parser'
require 'vba_documents/object_store'

RSpec.describe 'VBADocument::V1::Uploads', retry: 3, type: :request do
  include VBADocuments::Fixtures

  let(:test_caller) { { 'caller' => 'tester' } }
  let(:client_stub) { instance_double(CentralMail::Service) }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:valid_doc) { get_fixture('valid_doc.pdf') }

  describe '#create /v1/uploads' do
    it 'returns a UUID and location' do
      with_settings(Settings.vba_documents.location,
                    prefix: 'https://fake.s3.url/foo/',
                    replacement: 'https://api.vets.gov/proxy/') do
        s3_client = instance_double(Aws::S3::Resource)
        allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
        s3_bucket = instance_double(Aws::S3::Bucket)
        s3_object = instance_double(Aws::S3::Object)
        allow(s3_client).to receive(:bucket).and_return(s3_bucket)
        allow(s3_bucket).to receive(:object).and_return(s3_object)
        allow(s3_object).to receive(:presigned_url).and_return(+'https://fake.s3.url/foo/guid')
        post '/services/vba_documents/v1/uploads'
        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)
        expect(json['data']['attributes']).to have_key('guid')
        expect(json['data']['attributes']['status']).to eq('pending')
        expect(json['data']['attributes']['location']).to eq('https://api.vets.gov/proxy/guid')
      end
    end

    it 'sets consumer name from X-Consumer-Username header' do
      post '/services/vba_documents/v1/uploads', params: nil, headers: { 'X-Consumer-Username': 'test consumer' }
      upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
      expect(upload.consumer_name).to eq('test consumer')
    end

    it 'sets consumer id from X-Consumer-ID header' do
      post '/services/vba_documents/v1/uploads',
           params: nil,
           headers: { 'X-Consumer-ID': '29090360-72a8-4b77-b5ea-6ea1c69c7d89' }
      upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
      expect(upload.consumer_id).to eq('29090360-72a8-4b77-b5ea-6ea1c69c7d89')
    end
  end

  describe '#show /v1/uploads/{id}' do
    let(:upload) { create(:upload_submission, status: 'pending') }
    let(:upload_in_flight) { create(:upload_submission, status: 'processing') }
    let(:upload_large_detail) { create(:upload_submission_large_detail) }

    it 'returns status of an upload submission' do
      get "/services/vba_documents/v1/uploads/#{upload.guid}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['guid']).to eq(upload.guid)
      expect(json['data']['attributes']['status']).to eq('pending')
      expect(json['data']['attributes']['location']).to be_nil
    end

    it 'returns not_found with data for a non-existent submission' do
      get '/services/vba_documents/v1/uploads/non_existent_guid'
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to be_an(Array)
      expect(json['errors'].size).to eq(1)
      status = json['errors'][0]
      expect(status['detail']).to include('non_existent_guid')
    end

    context 'when status refresh raises a Common::Exceptions::GatewayTimeout exception' do
      before do
        allow(CentralMail::Service).to receive(:new).and_return(client_stub)
        allow(client_stub).to receive(:status).and_raise(Common::Exceptions::GatewayTimeout)
      end

      it 'returns the cached status' do
        get "/services/vba_documents/v1/uploads/#{upload_in_flight.guid}"
        expect(response).to have_http_status(:ok)
        json_attributes = JSON.parse(response.body)['data']['attributes']
        expect(json_attributes['guid']).to eq(upload_in_flight.guid)
        expect(json_attributes['status']).to eq('processing')
      end

      it 'logs a message to rails logger with log_level :warn' do
        expected_log = "Status refresh failed for submission on uploads#show, GUID: #{upload_in_flight.guid}"
        expect(Rails.logger).to receive(:warn).with(expected_log, Common::Exceptions::GatewayTimeout)
        get "/services/vba_documents/v1/uploads/#{upload_in_flight.guid}"
      end
    end

    context 'when status refresh raises a Common::Exceptions::BadGateway exception' do
      before do
        allow_any_instance_of(VBADocuments::UploadSubmission)
          .to receive(:refresh_status!).and_raise(Common::Exceptions::BadGateway)
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns the cached status' do
        get "/services/vba_documents/v1/uploads/#{upload_in_flight.guid}"
        expect(response).to have_http_status(:ok)
        json_attributes = JSON.parse(response.body)['data']['attributes']
        expect(json_attributes['guid']).to eq(upload_in_flight.guid)
        expect(json_attributes['status']).to eq('processing')
      end

      it 'logs a message to rails logger with log_level :warn' do
        expected_log = "Status refresh failed for submission on uploads#show, GUID: #{upload_in_flight.guid}"
        expect(Rails.logger).to receive(:warn).with(expected_log, Common::Exceptions::BadGateway)
        get "/services/vba_documents/v1/uploads/#{upload_in_flight.guid}"
      end
    end

    it 'keeps the displayed detail to 200 characters or less' do
      get "/services/vba_documents/v1/uploads/#{upload_large_detail.guid}"
      json = JSON.parse(response.body)
      length = VBADocuments::UploadSerializer::MAX_DETAIL_DISPLAY_LENGTH
      expect(json['data']['attributes']['detail'].length).to be <= length + 3
      expect(json['data']['attributes']['detail']).to match(/.*\.\.\.$/)
      get "/services/vba_documents/v1/uploads/#{upload.guid}"
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['detail']).to eql(upload.detail.to_s)
    end

    context 'line of business' do
      before do
        @md = JSON.parse(valid_metadata)
        @upload_submission = VBADocuments::UploadSubmission.new
        @upload_submission.update(status: 'uploaded')
        allow_any_instance_of(Tempfile).to receive(:size).and_return(1) # must be > 0 or submission will error w/DOC107
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'metadata' => @md.to_json, 'content' => valid_doc }
        }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive_messages(status: 200, body: [[], []].to_json, success?: true)
        allow(VBADocuments::PayloadManager).to receive(:download_raw_file) { [Tempfile.new, Time.zone.now] }
        expect(client_stub).to receive(:upload) {
          faraday_response
        }
        expect(client_stub).to receive(:status) {
          faraday_response
        }
      end

      it 'displays the line of business' do
        @md['businessLine'] = 'CMP'
        VBADocuments::UploadProcessor.new.perform(@upload_submission.guid, test_caller)
        get "/services/vba_documents/v1/uploads/#{@upload_submission.guid}"
        json = JSON.parse(response.body)
        pdf_data = json['data']['attributes']['uploaded_pdf']
        expect(pdf_data['line_of_business']).to eq('CMP')
        expect(pdf_data['submitted_line_of_business']).to be_nil
      end

      # for ticket: https://vajira.max.gov/browse/API-5293
      # production was broken, the pull request below fixes it.  This test ensures it never comes back.
      # https://github.com/department-of-veterans-affairs/vets-api/pull/6186
      it 'succeeds when giving a status on legacy data' do
        @md['businessLine'] = 'CMP'
        @upload_submission.metadata = {}
        @upload_submission.save!
        VBADocuments::UploadProcessor.new.perform(@upload_submission.guid, test_caller)
        get "/services/vba_documents/v1/uploads/#{@upload_submission.guid}"
        expect(response).to have_http_status(:ok)
      end
    end

    it 'returns not_found for an expired submission' do
      upload.update(status: 'expired')
      get "/services/vba_documents/v1/uploads/#{upload.guid}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('expired')
    end

    context 'with vbms complete' do
      let!(:vbms_upload) { create(:upload_submission, status: 'vbms') }

      it 'reports status of vbms' do
        get "/services/vba_documents/v1/uploads/#{vbms_upload.guid}"
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('vbms')
      end
    end

    context 'with error status' do
      let!(:error_upload) { create(:upload_submission, :status_error) }

      it 'returns json api errors' do
        get "/services/vba_documents/v1/uploads/#{error_upload.guid}"
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('error')
      end
    end

    it 'allows updating of the status' do
      with_settings(
        Settings.vba_documents,
        enable_status_override: true
      ) do
        starting_status = upload.status
        get(
          "/services/vba_documents/v1/uploads/#{upload.guid}",
          params: nil,
          headers: { 'Status-Override' => 'vbms' }
        )
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['status']).not_to eq(starting_status)
      end
    end
  end

  describe '#download /v1/uploads/{id}' do
    let(:upload) { create(:upload_submission) }
    let(:valid_doc) { get_fixture('valid_doc.pdf') }
    let(:valid_metadata) { get_fixture('valid_metadata.json').read }
    let(:invalid_doc) { get_fixture('invalid_multipart_no_partname.blob') }

    let(:valid_parts) do
      {
        'metadata' => valid_metadata,
        'content' => valid_doc
      }
    end

    it "returns a 404 if feature (via setting) isn't enabled" do
      with_settings(Settings.vba_documents, enable_download_endpoint: false) do
        get "/services/vba_documents/v1/uploads/#{upload.guid}/download"
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'returns a 200 with content-type of zip' do
      objstore = instance_double(VBADocuments::ObjectStore)
      version = instance_double(Aws::S3::ObjectVersion)
      bucket = instance_double(Aws::S3::Bucket)
      obj = instance_double(Aws::S3::Object)
      allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
      allow(objstore).to receive(:download)
      allow(objstore).to receive_messages(first_version: version, bucket:)
      allow(bucket).to receive(:object).and_return(obj)
      allow(obj).to receive(:exists?).and_return(true)
      allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }

      get "/services/vba_documents/v1/uploads/#{upload.guid}/download"
      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/zip')
    end

    it '200S even with an invalid doc' do
      allow(VBADocuments::PayloadManager).to receive(:download_raw_file).and_return(invalid_doc)
      get "/services/vba_documents/v1/uploads/#{upload.guid}/download"
      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/zip')
    end

    it 'returns a 404 if deleted from s3' do
      objstore = instance_double(VBADocuments::ObjectStore)
      version = instance_double(Aws::S3::ObjectVersion)
      bucket = instance_double(Aws::S3::Bucket)
      obj = instance_double(Aws::S3::Object)
      allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
      allow(objstore).to receive(:download)
      allow(objstore).to receive_messages(first_version: version, bucket:)
      allow(bucket).to receive(:object).and_return(obj)
      allow(obj).to receive(:exists?).and_return(false)
      allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }

      get "/services/vba_documents/v1/uploads/#{upload.guid}/download"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#validate_document /v1/uploads/validate_document' do
    let(:request_path) { '/services/vba_documents/v1/uploads/validate_document' }
    let(:request_validator) { instance_double(VBADocuments::DocumentRequestValidator) }
    let(:successful_validation_result) do
      {
        data: {
          type: 'documentValidation',
          attributes: {
            status: 'valid'
          }
        }
      }
    end
    let(:failed_validation_result) do
      {
        errors: [
          {
            title: 'error',
            detail: 'error detail',
            status: '422'
          }
        ]
      }
    end

    it 'returns a 200 if no validation errors are present' do
      allow(VBADocuments::DocumentRequestValidator).to receive(:new).and_return(request_validator)
      allow(request_validator).to receive(:validate).and_return(successful_validation_result)

      post request_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(successful_validation_result.to_json)
    end

    it 'returns a 422 if validation errors are present' do
      allow(VBADocuments::DocumentRequestValidator).to receive(:new).and_return(request_validator)
      allow(request_validator).to receive(:validate).and_return(failed_validation_result)

      post request_path
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to eq(failed_validation_result.to_json)
    end

    it "returns a 404 if feature (via setting) isn't enabled" do
      with_settings(Settings.vba_documents, enable_validate_document_endpoint: false) do
        post request_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
