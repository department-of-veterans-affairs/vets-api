# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/vba_document_fixtures'

require_dependency 'vba_documents/object_store'
require_dependency 'vba_documents/multipart_parser'

RSpec.describe 'VBA Document Uploads Endpoint', type: :request, retry: 3 do
  include VBADocuments::Fixtures


  describe '#submit /v2/uploads/submit' do

    let(:valid_attachments) do
      {     attachment1: Rack::Test::UploadedFile.new(get_fixture('valid_doc.pdf').path, 'application/pdf',
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

    it 'returns a UUID with status of uploaded and populated pdf metadata with a valid post' do
      post '/services/vba_documents/v2/uploads/submit',
      params: {}.merge(valid_metadata).merge(valid_content).merge(valid_attachments)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']).to have_key('guid')
      expect(json['data']['attributes']['status']).to eq('uploaded')
      uploaded_pdf = json['data']['attributes']['uploaded_pdf']
      expect(uploaded_pdf['total_documents']).to eq(3)
      expect(uploaded_pdf['content']['dimensions']['oversized_pdf']).to eq(false)
      expect(uploaded_pdf['content']['attachments'].first['dimensions']['oversized_pdf']).to eq(false)
      expect(uploaded_pdf['content']['attachments'].last['dimensions']['oversized_pdf']).to eq(false)
    end
  end
end
