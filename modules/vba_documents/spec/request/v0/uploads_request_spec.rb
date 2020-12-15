# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/vba_document_fixtures'

require_dependency 'vba_documents/object_store'
require_dependency 'vba_documents/multipart_parser'

RSpec.describe 'VBA Document Uploads Endpoint', type: :request do
  include VBADocuments::Fixtures

  describe '#create /v0/uploads' do
    it 'returns a UUID and location' do
      with_settings(Settings.vba_documents.location,
                    'prefix': 'https://fake.s3.url/foo/',
                    'replacement': 'https://api.vets.gov/proxy/') do
        s3_client = instance_double(Aws::S3::Resource)
        allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
        s3_bucket = instance_double(Aws::S3::Bucket)
        s3_object = instance_double(Aws::S3::Object)
        allow(s3_client).to receive(:bucket).and_return(s3_bucket)
        allow(s3_bucket).to receive(:object).and_return(s3_object)
        allow(s3_object).to receive(:presigned_url).and_return(+'https://fake.s3.url/foo/guid')
        post '/services/vba_documents/v0/uploads'
        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)
        expect(json['data']['attributes']).to have_key('guid')
        expect(json['data']['attributes']['status']).to eq('pending')
        expect(json['data']['attributes']['location']).to eq('https://api.vets.gov/proxy/guid')
      end
    end

    it 'sets consumer name from X-Consumer-Username header' do
      post '/services/vba_documents/v0/uploads', params: nil, headers: { 'X-Consumer-Username': 'test consumer' }
      upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
      expect(upload.consumer_name).to eq('test consumer')
    end

    it 'sets consumer id from X-Consumer-ID header' do
      post '/services/vba_documents/v0/uploads',
           params: nil,
           headers: { 'X-Consumer-ID': '29090360-72a8-4b77-b5ea-6ea1c69c7d89' }
      upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
      expect(upload.consumer_id).to eq('29090360-72a8-4b77-b5ea-6ea1c69c7d89')
    end
  end

  describe '#show /v0/uploads/{id}' do
    let(:upload) { FactoryBot.create(:upload_submission) }

    it 'returns status of an upload submission' do
      get "/services/vba_documents/v0/uploads/#{upload.guid}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['guid']).to eq(upload.guid)
      expect(json['data']['attributes']['status']).to eq('pending')
      expect(json['data']['attributes']['location']).to be_nil
    end

    it 'returns not_found with data for a non-existent submission' do
      get '/services/vba_documents/v0/uploads/non_existent_guid'
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['guid']).to eq('non_existent_guid')
      expect(json['data']['attributes']['status']).to eq('error')
    end

    it 'returns not_found for an expired submission' do
      upload.update(status: 'expired')
      get "/services/vba_documents/v0/uploads/#{upload.guid}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('expired')
    end

    context 'with vbms complete' do
      let!(:vbms_upload) { FactoryBot.create(:upload_submission, status: 'vbms') }

      it 'reports status of success' do
        get "/services/vba_documents/v0/uploads/#{vbms_upload.guid}"
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('success')
      end
    end

    it 'allows updating of the status' do
      with_settings(
        Settings.vba_documents,
        enable_status_override: true
      ) do
        starting_status = upload.status
        get(
          "/services/vba_documents/v0/uploads/#{upload.guid}",
          params: nil,
          headers: { 'Status-Override' => 'vbms' }
        )
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['status']).not_to eq(starting_status)
      end
    end
  end

  describe '#download /v0/uploads/{id}' do
    let(:upload) { FactoryBot.create(:upload_submission) }
    let(:valid_doc) { get_fixture('valid_doc.pdf') }
    let(:valid_metadata) { get_fixture('valid_metadata.json').read }
    let(:invalid_doc) { get_fixture('invalid_multipart_no_partname.blob') }

    let(:valid_parts) do
      { 'metadata' => valid_metadata,
        'content' => valid_doc }
    end

    it "raises if settings aren't set" do
      with_settings(Settings.vba_documents, enable_download_endpoint: false) do
        get "/services/vba_documents/v0/uploads/#{upload.guid}/download"
        expect(response.status).to eq(404)
      end
    end
    it 'returns a 200 with content-type of zip' do
      objstore = instance_double(VBADocuments::ObjectStore)
      version = instance_double(Aws::S3::ObjectVersion)
      allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
      allow(objstore).to receive(:first_version).and_return(version)
      allow(objstore).to receive(:download)
      allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }

      get "/services/vba_documents/v0/uploads/#{upload.guid}/download"
      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/zip')
    end

    it '200S even with an invalid doc' do
      allow(VBADocuments::PayloadManager).to receive(:download_raw_file).and_return(invalid_doc)
      get "/services/vba_documents/v0/uploads/#{upload.guid}/download"
      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/zip')
    end
  end
end
