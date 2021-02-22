# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/vba_document_fixtures'

require_dependency 'vba_documents/object_store'
require_dependency 'vba_documents/multipart_parser'

RSpec.describe 'VBA Document Uploads Endpoint', type: :request, retry: 3 do
  include VBADocuments::Fixtures

  # need a larger limit for sending raw data (base_64 for example)
  Rack::Utils.key_space_limit = 65_536 * 5
  SUBMIT_ENDPOINT = '/services/vba_documents/v2/uploads/submit'

  def build_fixture(fixture, is_metadata = false)
    fixture_path = get_fixture(fixture).path
    content_type = is_metadata ? 'application/json' : 'application/pdf'
    Rack::Test::UploadedFile.new(fixture_path, content_type, !is_metadata)
  end

  def invalidate_metadata(key, value = nil, delete_key = false)
    fixture = get_fixture('valid_metadata.json')
    metadata = JSON.parse(File.read(fixture))
    metadata[key] = value
    metadata.delete(key) if delete_key
    Rack::Test::UploadedFile.new(
        StringIO.new(metadata.to_json),'application/json', false, original_filename: 'metadata.json')
  end

  describe '#submit /v2/uploads/submit' do
    let(:valid_content) do
      {content: build_fixture('valid_doc.pdf')}
    end

    let(:valid_attachments) do
      {attachment1: build_fixture('valid_doc.pdf'),
       attachment2: build_fixture('valid_doc.pdf')
      }
    end

    let(:valid_metadata) do
      {metadata: build_fixture('valid_metadata.json', true)}
    end

    after(:each) do
      guid = @attributes['guid']
      upload = VBADocuments::UploadFile.find_by_guid(guid)
      expect(upload).to be_uploaded
    end

    it 'returns a UUID with status of uploaded and populated pdf metadata with a valid post' do
      post SUBMIT_ENDPOINT,
           params: {}.merge(valid_metadata).merge(valid_content).merge(valid_attachments)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      @attributes = json['data']['attributes']
      expect(@attributes).to have_key('guid')
      expect(@attributes['status']).to eq('uploaded')
      uploaded_pdf = @attributes['uploaded_pdf']
      expect(uploaded_pdf['total_documents']).to eq(3)
      expect(uploaded_pdf['content']['dimensions']['oversized_pdf']).to eq(false)
      expect(uploaded_pdf['content']['attachments'].first['dimensions']['oversized_pdf']).to eq(false)
      expect(uploaded_pdf['content']['attachments'].last['dimensions']['oversized_pdf']).to eq(false)
    end

    it 'processes base64 requests' do
      post SUBMIT_ENDPOINT, params: get_fixture('base_64').read
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      @attributes = json['data']['attributes']
      expect(@attributes).to have_key('guid')
      expect(@attributes['status']).to eq('error')
      expect(@attributes['uploaded_pdf']).to have_key('total_documents')
      expect(@attributes['uploaded_pdf']).to have_key('total_pages')
      expect(@attributes['uploaded_pdf']).to have_key('content')
      expect(@attributes['uploaded_pdf']['content']['dimensions']['oversized_pdf']).to be_truthy
    end

    context 'with invalid metadata' do
      %w[veteranFirstName veteranLastName fileNumber zipCode].each do |key|
        it "Returns a 400 error when #{key} is nil" do
          # set key to be nil in metadata
          metadata = {metadata: invalidate_metadata(key)}
          post SUBMIT_ENDPOINT, params: {}.merge(metadata).merge(valid_content).merge(valid_attachments)
          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          @attributes = json['data']['attributes']
          expect(@attributes['status']).to eq('error')
          expect(@attributes['code']).to eq('DOC102')
          expect(@attributes['detail']).to eq("Non-string values for keys: #{key}")
        end

        it "Returns a 400 error when #{key} is missing" do
          # remove the key from metadata
          metadata = {metadata: invalidate_metadata(key, '', true)}
          post SUBMIT_ENDPOINT, params: {}.merge(metadata).merge(valid_content).merge(valid_attachments)
          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          @attributes = json['data']['attributes']
          expect(@attributes['status']).to eq('error')
          expect(@attributes['code']).to eq('DOC102')
          expect(@attributes['detail']).to eq("Missing required keys: #{key}")
        end

        if key.eql?('fileNumber')
          it "Returns an error when #{key} is not a string" do
            # make fileNumber a non-string value
            metadata = {metadata: invalidate_metadata(key, 123456789)}
            post SUBMIT_ENDPOINT, params: {}.merge(metadata).merge(valid_content).merge(valid_attachments)
            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            @attributes = json['data']['attributes']
            expect(@attributes['status']).to eq('error')
            expect(@attributes['code']).to eq('DOC102')
            expect(@attributes['detail']).to eq("Non-string values for keys: #{key}")
          end
        end
      end
    end
  end
end
