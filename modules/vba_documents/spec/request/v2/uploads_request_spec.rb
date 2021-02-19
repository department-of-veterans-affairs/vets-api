# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/vba_document_fixtures'

require_dependency 'vba_documents/object_store'
require_dependency 'vba_documents/multipart_parser'

RSpec.describe 'VBA Document Uploads Endpoint', type: :request, retry: 3 do
  include VBADocuments::Fixtures

  #need a larger limit for sending raw data (base_64 for example)
  Rack::Utils.key_space_limit = 65536 * 5
  SUBMIT_ENDPOINT = '/services/vba_documents/v2/uploads/submit'

  describe '#submit /v2/uploads/submit' do
    let(:valid_attachments) do
      {attachment1: Rack::Test::UploadedFile.new(get_fixture('valid_doc.pdf').path, 'application/pdf',
                                                 true),
       attachment2: Rack::Test::UploadedFile.new(get_fixture('valid_doc.pdf').path, 'application/pdf',
                                                 true)
      }
    end

    let(:valid_metadata) do
      {metadata: Rack::Test::UploadedFile.new(get_fixture('valid_metadata.json').path, 'application/json',
                                              false)}
    end

    let(:valid_content) do
      {content: Rack::Test::UploadedFile.new(get_fixture('valid_doc.pdf').path, 'application/pdf',
                                             true)}
    end

    after(:each) do
      guid = @attributes['guid']
      upload = VBADocuments::UploadFile.find_by_guid(guid)
      expect(upload.uploaded?).to be_truthy
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
  end
end
