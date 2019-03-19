# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VBA Document Uploads Endpoint', type: :request do
  describe '#create /v0/uploads' do
    it 'should return a UUID and location' do
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

    it 'should set consumer name from X-Consumer-Username header' do
      post '/services/vba_documents/v0/uploads', params: nil, headers: { 'X-Consumer-Username': 'test consumer' }
      upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
      expect(upload.consumer_name).to eq('test consumer')
    end

    it 'should set consumer id from X-Consumer-ID header' do
      post '/services/vba_documents/v0/uploads',
           params: nil,
           headers: { 'X-Consumer-ID': '29090360-72a8-4b77-b5ea-6ea1c69c7d89' }
      upload = VBADocuments::UploadSubmission.order(created_at: :desc).first
      expect(upload.consumer_id).to eq('29090360-72a8-4b77-b5ea-6ea1c69c7d89')
    end
  end

  describe '#show /v0/uploads/{id}' do
    let(:upload) { FactoryBot.create(:upload_submission) }

    it 'should return status of an upload submission' do
      get "/services/vba_documents/v0/uploads/#{upload.guid}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['guid']).to eq(upload.guid)
      expect(json['data']['attributes']['status']).to eq('pending')
      expect(json['data']['attributes']['location']).to be_nil
    end

    it 'should return not_found with data for a non-existent submission' do
      get '/services/vba_documents/v0/uploads/non_existent_guid'
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['guid']).to eq('non_existent_guid')
      expect(json['data']['attributes']['status']).to eq('error')
    end

    it 'should return not_found for an expired submission' do
      upload.update(status: 'expired')
      get "/services/vba_documents/v0/uploads/#{upload.guid}"
      expect(response).to have_http_status(:not_found)
    end

    it 'should allow updating of the status' do
      with_settings(
        Settings.vba_documents,
        enable_status_override: true
      ) do
        starting_status = upload.status
        get(
          "/services/vba_documents/v0/uploads/#{upload.guid}",
          params: nil,
          headers: { 'Status-Override' => 'success' }
        )
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['status']).not_to eq(starting_status)
      end
    end
  end
end
