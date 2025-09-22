# frozen_string_literal: true

require 'rails_helper'
require './lib/webhooks/utilities'
require 'vba_documents/payload_manager'
require_relative '../../support/vba_document_fixtures'
require 'vba_documents/object_store'
require 'vba_documents/multipart_parser'

RSpec.describe 'VBADocument::V2::Uploads', skip: 'v2 will never be launched in vets-api', type: :request do
  include VBADocuments::Fixtures

  load('./modules/vba_documents/config/routes.rb')

  let(:test_caller) { { 'caller' => 'tester' } }
  let(:client_stub) { instance_double(CentralMail::Service) }
  let(:faraday_response) { instance_double(Faraday::Response) }
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

      it 'returns a UUID and location', skip: 'Temporarily skip examples not working' do
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
                   observers:
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
                   observers:
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
               observers:
             },
             headers: dev_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
