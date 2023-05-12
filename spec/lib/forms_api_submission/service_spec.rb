# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'
require 'forms_api_submission/service'

describe FormsApiSubmission::Service do
  mock_metadata = '
    {"veteranFirstName"=>"Veteran", "veteranLastName"=>"Surname", "fileNumber"=>"123456789",
    "zipCode"=>"12345", "source"=>"test", "docType"=>"test", "businessLine"=>"OTH"}
    '

  before(:all) do
    @service = FormsApiSubmission::Service.new
  end

  describe 'get uuid and upload location' do
    it 'retrieves uuid and upload location from the Lighthouse API' do
      VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
        response = @service.get_upload_location
        expect(response.status).to equal(200)
      end
    end
  end

  describe 'generate metadata file' do
    it 'generates a json file from the metadata' do
      @service.generate_tmp_metadata(mock_metadata)
      expect(Dir['tmp/*.FormsApi.metadata.json'].any?).to equal(true)
    ensure
      metadata_file = Dir['tmp/*.FormsApi.metadata.json'][0]
      Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
    end
  end

  describe 'upload doc' do
    it 'upload doc to mock location' do
      VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
        mock_upload_url = 'https://sandbox-api.va.gov/services_user_content/vba_documents/id-path-doesnt-matter'
        mock_file_path = "#{Common::FileHelpers.random_file_path}-mock-upload.pdf"
        Prawn::Document.new.render_file mock_file_path
        response = @service.upload_doc(upload_url: mock_upload_url, file: mock_file_path, metadata: mock_metadata)
        expect(response.status).to equal(200)
      ensure
        metadata_file = Dir['tmp/*.FormsApi.metadata.json'][0]
        pdf_file = Dir['tmp/*-mock-upload.pdf'][0]
        Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
        Common::FileHelpers.delete_file_if_exists(pdf_file) if defined?(pdf_file)
      end
    end
  end
end
