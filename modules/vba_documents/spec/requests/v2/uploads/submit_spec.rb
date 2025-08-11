# frozen_string_literal: true

require 'rails_helper'
require './lib/central_mail/utilities'
require_relative '../../../support/vba_document_fixtures'

# rubocop:disable Style/OptionalBooleanParameter
RSpec.describe 'VBADocument::V2::Uploads::Submit',
               retry: 3, skip: 'v2 will never be launched in vets-api', type: :request do
  include VBADocuments::Fixtures

  load('./modules/vba_documents/config/routes.rb')

  # need a larger limit for sending raw data (base_64 for example)
  Rack::Utils.key_space_limit = 65_536 * 5

  let(:submit_endpoint) { '/services/vba_documents/v2/uploads/submit' }

  def build_fixture(fixture, is_metadata = false, is_erb = false)
    fixture_path = if is_erb && is_metadata
                     get_erbed_fixture(fixture).path
                   else
                     get_fixture(fixture).path
                   end
    content_type = is_metadata ? 'application/json' : 'application/pdf'
    Rack::Test::UploadedFile.new(fixture_path, content_type, !is_metadata)
  end

  def invalidate_metadata(key, value = nil, delete_key = false)
    fixture = get_fixture('valid_metadata.json')
    metadata = JSON.parse(File.read(fixture))
    metadata[key] = value
    metadata.delete(key) if delete_key
    Rack::Test::UploadedFile.new(
      StringIO.new(metadata.to_json), 'application/json', false, original_filename: 'metadata.json'
    )
  end

  describe '#submit /v2/uploads/submit' do
    let(:missing_first) { { metadata: build_fixture('missing_first_metadata.json', true) } }
    let(:missing_last) { { metadata: build_fixture('missing_last_metadata.json', true) } }

    let(:bad_with_digits_first) do
      { metadata: build_fixture('bad_with_digits_first_metadata.json', true) }
    end
    let(:bad_with_funky_characters_last) do
      { metadata: build_fixture('bad_with_funky_characters_last_metadata.json', true) }
    end
    let(:dashes_slashes_first_last) do
      { metadata: build_fixture('dashes_slashes_first_last_metadata.json', true) }
    end
    let(:name_too_long_metadata) do
      { metadata: build_fixture('name_too_long_metadata.json.erb', true, true) }
    end
    let(:valid_metadata_space_in_name) do
      { metadata: build_fixture('valid_metadata_space_in_name.json', true) }
    end

    let(:valid_content) do
      { content: build_fixture('valid_doc.pdf') }
    end

    let(:valid_attachments) do
      { attachment1: build_fixture('valid_doc.pdf'),
        attachment2: build_fixture('valid_doc.pdf') }
    end

    let(:valid_metadata) do
      { metadata: build_fixture('valid_metadata.json', true) }
    end

    let(:invalid_attachment_oversized) do
      { attachment1: build_fixture('10x102.pdf'),
        attachment2: build_fixture('valid_doc.pdf') }
    end

    let(:invalid_content_missing) do
      { content: nil }
    end

    let(:invalid_attachment_missing) do
      { attachment1: nil }
    end

    after do
      if @attributes
        guid = @attributes['guid']
        upload = VBADocuments::UploadFile.find_by(guid:)
        expect(upload).to be_uploaded
      end
    end

    it 'returns a UUID with status of uploaded and populated pdf metadata with a valid post' do
      post submit_endpoint,
           params: {}.merge(valid_metadata).merge(valid_content).merge(valid_attachments)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      @attributes = json['data']['attributes']
      expect(@attributes).to have_key('guid')
      expect(@attributes['status']).to eq('uploaded')
      uploaded_pdf = @attributes['uploaded_pdf']
      expect(uploaded_pdf['total_documents']).to eq(3)
      expect(uploaded_pdf['content']['dimensions']['oversized_pdf']).to be(false)
      expect(uploaded_pdf['content']['attachments'].first['dimensions']['oversized_pdf']).to be(false)
      expect(uploaded_pdf['content']['attachments'].last['dimensions']['oversized_pdf']).to be(false)
    end

    it 'processes base64 requests' do
      post submit_endpoint, params: get_fixture('base_64').read
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      @attributes = json['data']['attributes']
      expect(@attributes).to have_key('guid')
      expect(@attributes['status']).to eq('uploaded')
      expect(@attributes['uploaded_pdf']).to have_key('total_documents')
      expect(@attributes['uploaded_pdf']).to have_key('total_pages')
      expect(@attributes['uploaded_pdf']).to have_key('content')
    end

    describe 'when an attachment is oversized' do
      let(:params) { {}.merge(valid_metadata).merge(valid_content).merge(invalid_attachment_oversized) }

      it 'returns a UUID with status of error' do
        post(submit_endpoint, params:)
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        @attributes = json['data']['attributes']
        expect(@attributes).to have_key('guid')
        expect(@attributes['status']).to eq('error')
        uploaded_pdf = @attributes['uploaded_pdf']
        expect(uploaded_pdf['total_documents']).to eq(3)
        expect(uploaded_pdf['content']['dimensions']['oversized_pdf']).to be(false)
        expect(uploaded_pdf['content']['attachments'].first['dimensions']['oversized_pdf']).to be(true)
        expect(uploaded_pdf['content']['attachments'].first['dimensions']['height']).to eq(102)
        expect(uploaded_pdf['content']['attachments'].first['dimensions']['width']).to eq(10)
        expect(uploaded_pdf['content']['attachments'].last['dimensions']['oversized_pdf']).to be(false)
      end
    end

    %i[dashes_slashes_first_last valid_metadata_space_in_name].each do |allowed|
      it "allows #{allowed} in names" do
        post submit_endpoint,
             params: {}.merge(send(allowed)).merge(valid_content)
        expect(response).to have_http_status(:ok)
      end
    end

    %i[missing_first missing_last bad_with_digits_first bad_with_funky_characters_last
       name_too_long_metadata].each do |bad|
      it "returns an error if the name field #{bad} is missing or has bad characters" do
        post submit_endpoint,
             params: {}.merge(send(bad)).merge(valid_content)
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        @attributes = json['data']['attributes']
        expect(@attributes['status']).to eq('error')
        expect(@attributes['code']).to eq('DOC102')
        expect(@attributes['detail']).to match(/^Invalid Veteran name/)
      end
    end

    it 'returns an error when a content is missing' do
      post submit_endpoint,
           params: {}.merge(valid_metadata).merge(invalid_content_missing).merge(valid_attachments)
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      @attributes = json['data']['attributes']
      expect(@attributes['status']).to eq('error')
      expect(@attributes['code']).to eq('DOC101')
      expect(@attributes['detail']).to eq('Missing content-type header')
    end

    it 'returns an error when an attachment is missing' do
      post submit_endpoint,
           params: {}.merge(valid_metadata).merge(valid_content).merge(invalid_attachment_missing)
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      @attributes = json['data']['attributes']
      expect(@attributes['status']).to eq('error')
      expect(@attributes['code']).to eq('DOC101')
      expect(@attributes['detail']).to eq('Missing content-type header')
    end

    CentralMail::Utilities::VALID_LOB.each_key do |key|
      it "consumes the valid line of business #{key}" do
        fixture = get_fixture('valid_metadata.json')
        metadata = JSON.parse(File.read(fixture))
        metadata['businessLine'] = key
        metadata_file = { metadata: Rack::Test::UploadedFile.new(
          StringIO.new(metadata.to_json), 'application/json', false,
          original_filename: 'metadata.json'
        ) }
        post submit_endpoint, params: {}.merge(metadata_file).merge(valid_content).merge(valid_attachments)
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        @attributes = json['data']['attributes']
        pdf_data = json['data']['attributes']['uploaded_pdf']
        expect(@attributes['status']).to eq('uploaded')
        expect(pdf_data['line_of_business']).to eq(key)
        expect(pdf_data['submitted_line_of_business']).to be_nil
      end
    end

    context 'with invalid metadata' do
      it 'Returns a 400 error when an invalid line of business is submitted' do
        fixture = get_fixture('valid_metadata.json')
        metadata = JSON.parse(File.read(fixture))
        metadata['businessLine'] = 'BAD_STATUS'
        metadata_file = { metadata: Rack::Test::UploadedFile.new(
          StringIO.new(metadata.to_json), 'application/json', false,
          original_filename: 'metadata.json'
        ) }
        post submit_endpoint, params: {}.merge(metadata_file).merge(valid_content).merge(valid_attachments)
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        @attributes = json['data']['attributes']
        expect(@attributes['status']).to eq('error')
        expect(@attributes['code']).to eq('DOC102')
        expect(@attributes['detail']).to start_with('Invalid businessLine provided')
        expect(@attributes['detail']).to match(/BAD_STATUS/)
      end

      %w[veteranFirstName veteranLastName fileNumber zipCode].each do |key|
        it "Returns a 400 error when #{key} is nil" do
          # set key to be nil in metadata
          metadata = { metadata: invalidate_metadata(key) }
          post submit_endpoint, params: {}.merge(metadata).merge(valid_content).merge(valid_attachments)
          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          @attributes = json['data']['attributes']
          expect(@attributes['status']).to eq('error')
          expect(@attributes['code']).to eq('DOC102')
          expect(@attributes['detail']).to eq("Non-string values for keys: #{key}")
        end

        it "Returns a 400 error when #{key} is missing" do
          # remove the key from metadata
          metadata = { metadata: invalidate_metadata(key, '', true) }
          post submit_endpoint, params: {}.merge(metadata).merge(valid_content).merge(valid_attachments)
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
            metadata = { metadata: invalidate_metadata(key, 123_456_789) }
            post submit_endpoint, params: {}.merge(metadata).merge(valid_content).merge(valid_attachments)
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
# rubocop:enable Style/OptionalBooleanParameter
