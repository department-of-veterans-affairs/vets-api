# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form1010CG::Attachments', type: :request do
  let(:endpoint) { 'http://localhost:3000/v0/form1010cg/attachments' }
  let(:headers) do
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      'HTTP_X_KEY_INFLECTION' => 'camel'
    }
  end
  let(:vcr_options) do
    {
      record: :none,
      allow_unused_http_interactions: false,
      match_requests_on: %i[method host body]
    }
  end

  def make_upload_request_with(file_fixture_path, content_type)
    request_options = {
      headers:,
      params: {
        attachment: {
          file_data: create_test_uploaded_file(file_fixture_path, content_type)
        }
      }
    }

    post(endpoint, **request_options)
  end

  def create_test_uploaded_file(file_fixture_path, content_type)
    # Create unique identifier per process/test to avoid race conditions
    process_id = ENV['TEST_ENV_NUMBER'].presence || SecureRandom.hex(4)
    source_path = Rails.root.join('spec', 'fixtures', 'files', file_fixture_path)

    # Create unique temp file per process
    temp_file = Tempfile.new(["test_#{process_id}_", File.extname(file_fixture_path)])
    temp_file.binmode

    File.open(source_path, 'rb') do |source|
      temp_file.write(source.read)
    end
    temp_file.rewind

    # Use the original filename, not the temp file path
    uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, content_type, file_fixture_path)

    # Store temp_file reference for cleanup
    uploaded_file.define_singleton_method(:cleanup!) do
      temp_file&.close
      temp_file&.unlink
    end

    uploaded_file
  end

  describe 'POST /v0/form1010cg/attachments' do
    after do
      Form1010cg::Attachment.delete_all
    end

    context 'with JPG' do
      let(:form_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }

      before do
        expect(SecureRandom).to receive(:uuid).and_call_original
        expect(SecureRandom).to receive(:uuid).and_return(form_attachment_guid) # when FormAttachment is initalized
        allow(SecureRandom).to receive(:uuid).and_call_original # Allow method to be called later in the req stack
      end

      it 'accepts a file upload' do
        VCR.use_cassette "s3/object/put/#{form_attachment_guid}/doctors-note.jpg", vcr_options do
          make_upload_request_with('doctors-note.jpg', 'image/jpg')

          expect(response).to have_http_status(:ok)

          res_body = JSON.parse(response.body)

          expect(res_body['data']).to be_present
          expect(res_body['data']['type']).to eq 'form1010cg_attachments'
          expect(res_body['data']['id'].to_i).to be > 0
          expect(res_body['data']['attributes']['guid']).to eq form_attachment_guid
        end
      end
    end

    context 'with PDF' do
      let(:form_attachment_guid) { '834d9f51-d0c7-4dc2-9f2e-9b722db98069' }

      before do
        expect(SecureRandom).to receive(:uuid).and_call_original
        expect(SecureRandom).to receive(:uuid).and_return(form_attachment_guid) # when FormAttachment is initalized
        allow(SecureRandom).to receive(:uuid).and_call_original # Allow method to be called later in the req stack
      end

      it 'accepts a file upload' do
        VCR.use_cassette "s3/object/put/#{form_attachment_guid}/doctors-note.pdf", vcr_options do
          make_upload_request_with('doctors-note.pdf', 'application/pdf')

          expect(response).to have_http_status(:ok)

          res_body = JSON.parse(response.body)

          expect(res_body['data']).to be_present
          expect(res_body['data']['type']).to eq 'form1010cg_attachments'
          expect(res_body['data']['id'].to_i).to be > 0
          expect(res_body['data']['attributes']['guid']).to eq form_attachment_guid
        end
      end
    end
  end

  private

  def create_test_uploaded_file(file_fixture_path, content_type)
    # Create unique identifier per process/test
    process_id = ENV['TEST_ENV_NUMBER'].presence || SecureRandom.hex(4)
    source_path = Rails.root.join('spec', 'fixtures', 'files', file_fixture_path)

    # Create process-specific temp directory
    temp_dir = Rails.root.join('tmp', 'test_uploads', "process_#{process_id}")
    FileUtils.mkdir_p(temp_dir)

    # Copy fixture to process-specific directory with original filename
    temp_file_path = temp_dir.join(file_fixture_path)
    FileUtils.copy_file(source_path, temp_file_path)

    uploaded_file = Rack::Test::UploadedFile.new(temp_file_path.to_s, content_type)

    # Add cleanup method to the uploaded file instance
    uploaded_file.define_singleton_method(:cleanup!) do
      FileUtils.rm_rf(temp_dir) if temp_dir.exist?
    end

    uploaded_file
  end
end
