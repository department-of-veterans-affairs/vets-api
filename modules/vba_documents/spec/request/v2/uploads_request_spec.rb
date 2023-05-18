# frozen_string_literal: true

require 'rails_helper'
require './lib/webhooks/utilities'
require 'vba_documents/payload_manager'
require_relative '../../support/vba_document_fixtures'
require 'vba_documents/object_store'

RSpec.describe 'VBA Document Uploads Endpoint', type: :request, retry: 3 do
  include VBADocuments::Fixtures

  load('./modules/vba_documents/config/routes.rb')

  let(:test_caller) { { 'caller' => 'tester' } }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:valid_doc) { get_fixture('valid_doc.pdf') }
  let(:dev_headers) do
    {
      'X-Consumer-ID': '59ac8ab0-1f28-43bd-8099-23adb561815d',
      'X-Consumer-Username': 'Development'
    }
  end
  let(:fixture_path) { './modules/vba_documents/spec/fixtures/subscriptions/' }

  describe '#create /v2/uploads' do
    context 'uploads' do
      before do
        s3_client = instance_double(Aws::S3::Resource)
        allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
        s3_bucket = instance_double(Aws::S3::Bucket)
        s3_object = instance_double(Aws::S3::Object)
        allow(s3_client).to receive(:bucket).and_return(s3_bucket)
        allow(s3_bucket).to receive(:object).and_return(s3_object)
        allow(s3_object).to receive(:presigned_url).and_return(+'https://fake.s3.url/foo/guid')
      end

      xit 'returns a UUID and location' do
        with_settings(Settings.vba_documents.location,
                      prefix: 'https://fake.s3.url/foo/',
                      replacement: 'https://api.vets.gov/proxy/') do
          post vba_documents.v2_uploads_path
          expect(response).to have_http_status(:accepted)
          json = JSON.parse(response.body)
          expect(json['data']['attributes']).to have_key('guid')
          expect(json['data']['attributes']['status']).to eq('pending')
          expect(json['data']['attributes']['location']).to eq('https://api.vets.gov/proxy/guid')
        end
      end

      it 'sets consumer name from X-Consumer-Username header' do
        post vba_documents.v2_uploads_path, params: nil, headers: { 'X-Consumer-Username': 'test consumer' }
        upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
        expect(upload.consumer_name).to eq('test consumer')
      end

      it 'sets consumer id from X-Consumer-ID header' do
        post vba_documents.v2_uploads_path,
             params: nil,
             headers: { 'X-Consumer-ID': '29090360-72a8-4b77-b5ea-6ea1c69c7d89' }
        upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
        expect(upload.consumer_id).to eq('29090360-72a8-4b77-b5ea-6ea1c69c7d89')
      end

      %i[file text].each do |multipart_fashion|
        xit "returns a UUID, location and observers when valid observers #{multipart_fashion} included" do
          with_settings(Settings.vba_documents.location,
                        prefix: 'https://fake.s3.url/foo/',
                        replacement: 'https://api.vets.gov/proxy/') do
            observers_json = File.read("#{fixture_path}subscriptions.json")
            observers = Rack::Test::UploadedFile.new("#{fixture_path}subscriptions.json", 'application/json')
            observers = observers_json if multipart_fashion == :text
            post vba_documents.v2_uploads_path,
                 params: {
                   'observers': observers
                 },
                 headers: dev_headers
            expect(response).to have_http_status(:accepted)
            json = JSON.parse(response.body)
            expect(json['data']['attributes']).to have_key('guid')
            expect(json['data']['attributes']['status']).to eq('pending')
            expect(json['data']['attributes']['location']).to eq('https://api.vets.gov/proxy/guid')
            expect(json['data']['attributes']['observers']).to eq(JSON.parse(observers_json)['subscriptions'])
          end
        end
      end

      %i[missing_event bad_URL unknown_event not_https duplicate_events not_JSON empty_array].each do |test_case|
        %i[file text].each do |multipart_fashion|
          it "returns error with invalid #{test_case} observers #{multipart_fashion}" do
            observers = if multipart_fashion == :file
                          Rack::Test::UploadedFile.new("#{fixture_path}invalid_subscription_#{test_case}.json",
                                                       'application/json')
                        else
                          File.read("#{fixture_path}invalid_subscription_#{test_case}.json")
                        end

            post vba_documents.v2_uploads_path,
                 params: {
                   'observers': observers
                 },
                 headers: dev_headers
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      it 'returns error if spanning multiple api names' do
        observers = File.read("#{fixture_path}subscriptions_multiple.json")

        post vba_documents.v2_uploads_path,
             params: {
               'observers': observers
             },
             headers: dev_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe '#show /v2/uploads/{id}' do
    let(:upload) { FactoryBot.create(:upload_submission, status: 'pending') }
    let(:upload_in_flight) { FactoryBot.create(:upload_submission, status: 'processing') }
    let(:upload_large_detail) { FactoryBot.create(:upload_submission_large_detail) }

    it 'returns status of an upload submission' do
      get vba_documents.v2_upload_path(upload.guid)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['guid']).to eq(upload.guid)
      expect(json['data']['attributes']['status']).to eq('pending')
      expect(json['data']['attributes']['location']).to be_nil
    end

    it 'returns not_found with data for a non-existent submission' do
      get vba_documents.v2_upload_path('non_existent_guid')
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
      get vba_documents.v2_upload_path(upload_large_detail.guid)
      json = JSON.parse(response.body)
      length = VBADocuments::UploadSerializer::MAX_DETAIL_DISPLAY_LENGTH
      expect(json['data']['attributes']['detail'].length).to be <= length + 3
      expect(json['data']['attributes']['detail']).to match(/.*\.\.\.$/)
      get vba_documents.v2_upload_path(upload.guid)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['detail']).to eql(upload.detail.to_s)
    end

    context 'line of business' do
      before do
        @md = JSON.parse(valid_metadata)
        @upload_submission = VBADocuments::UploadSubmission.new
        @upload_submission.update(status: 'uploaded')
        allow_any_instance_of(VBADocuments::UploadProcessor).to receive(:cancelled?).and_return(false)
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'metadata' => @md.to_json, 'content' => valid_doc }
        }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive(:status).and_return(200)
        allow(faraday_response).to receive(:body).and_return([[], []].to_json)
        allow(faraday_response).to receive(:success?).and_return(true)
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
        get vba_documents.v2_upload_path(@upload_submission.guid)
        json = JSON.parse(response.body)
        pdf_data = json['data']['attributes']['uploaded_pdf']
        expect(pdf_data['line_of_business']).to eq('CMP')
        expect(pdf_data['submitted_line_of_business']).to eq(nil)
      end

      # for ticket: https://vajira.max.gov/browse/API-5293
      # production was broken, the pull request below fixes it.  This test ensures it never comes back.
      # https://github.com/department-of-veterans-affairs/vets-api/pull/6186
      it 'succeeds when giving a status on legacy data' do
        @md['businessLine'] = 'CMP'
        @upload_submission.metadata = {}
        @upload_submission.save!
        VBADocuments::UploadProcessor.new.perform(@upload_submission.guid, test_caller)
        get vba_documents.v2_upload_path(@upload_submission.guid)
        expect(response).to have_http_status(:ok)
      end
    end

    it 'returns not_found for an expired submission' do
      upload.update(status: 'expired')
      get vba_documents.v2_upload_path(upload.guid)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('expired')
    end

    context 'with vbms complete' do
      let!(:vbms_upload) { FactoryBot.create(:upload_submission, status: 'vbms') }

      it 'reports status of vbms' do
        get vba_documents.v2_upload_path(vbms_upload.guid)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('vbms')
      end
    end

    context 'with error status' do
      let!(:error_upload) { FactoryBot.create(:upload_submission, :status_error) }

      it 'returns json api errors' do
        get vba_documents.v2_upload_path(error_upload.guid)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('error')
      end
    end

    it 'allows updating of the status' do
      with_settings(
        Settings.vba_documents,
        enable_status_override: true
      ) do
        starting_status = upload.status
        get(vba_documents.v2_upload_path(upload.guid),
            params: nil,
            headers: { 'Status-Override' => 'vbms' })
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['status']).not_to eq(starting_status)
      end
    end
  end

  describe '#download /v2/uploads/{id}' do
    let(:upload) { FactoryBot.create(:upload_submission) }
    let(:valid_doc) { get_fixture('valid_doc.pdf') }
    let(:valid_metadata) { get_fixture('valid_metadata.json').read }
    let(:invalid_doc) { get_fixture('invalid_multipart_no_partname.blob') }

    let(:valid_parts) do
      {
        'metadata' => valid_metadata,
        'content' => valid_doc
      }
    end

    it "raises if settings aren't set" do
      with_settings(Settings.vba_documents, enable_download_endpoint: false) do
        get vba_documents.v2_upload_download_path(upload.guid)
        expect(response.status).to eq(404)
      end
    end

    it 'returns a 200 with content-type of zip' do
      objstore = instance_double(VBADocuments::ObjectStore)
      version = instance_double(Aws::S3::ObjectVersion)
      bucket = instance_double(Aws::S3::Bucket)
      obj = instance_double(Aws::S3::Object)
      allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
      allow(objstore).to receive(:first_version).and_return(version)
      allow(objstore).to receive(:download)
      allow(objstore).to receive(:bucket).and_return(bucket)
      allow(bucket).to receive(:object).and_return(obj)
      allow(obj).to receive(:exists?).and_return(true)
      allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }

      get vba_documents.v2_upload_download_path(upload.guid)
      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/zip')
    end

    it '200S even with an invalid doc' do
      allow(VBADocuments::PayloadManager).to receive(:download_raw_file).and_return(invalid_doc)
      get vba_documents.v2_upload_download_path(upload.guid)
      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/zip')
    end

    it 'returns a 404 if deleted from s3' do
      objstore = instance_double(VBADocuments::ObjectStore)
      version = instance_double(Aws::S3::ObjectVersion)
      bucket = instance_double(Aws::S3::Bucket)
      obj = instance_double(Aws::S3::Object)
      allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
      allow(objstore).to receive(:first_version).and_return(version)
      allow(objstore).to receive(:download)
      allow(objstore).to receive(:bucket).and_return(bucket)
      allow(bucket).to receive(:object).and_return(obj)
      allow(obj).to receive(:exists?).and_return(false)
      allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }

      get vba_documents.v2_upload_download_path(upload.guid)
      expect(response.status).to eq(404)
    end
  end
end
