# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'
require 'simple_forms_api_submission/service'

describe SimpleFormsApiSubmission::Service do
  let(:mock_metadata) do
    '{"veteranFirstName"=>"Veteran", "veteranLastName"=>"Surname", "fileNumber"=>"123456789",
    "zipCode"=>"12345", "source"=>"test", "docType"=>"test", "businessLine"=>"OTH"}'
  end

  let(:simple_forms_service) { SimpleFormsApiSubmission::Service.new }
  let(:file_seed) { 'some-unique-simple-forms-service-spec-file-seed' }

  before { allow(SecureRandom).to receive(:hex).and_return(file_seed) }

  describe 'get uuid and upload location' do
    it 'retrieves uuid and upload location from the Lighthouse API' do
      VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
        response = simple_forms_service.get_upload_location
        expect(response.status).to equal(200)
      end
    end
  end

  describe 'generate metadata file' do
    let(:mock_file_path_metadata) { "#{file_seed}.SimpleFormsApi.metadata.json" }

    it 'generates a json file from the metadata' do
      simple_forms_service.generate_tmp_metadata(mock_metadata)
      expect(Dir['clamav_tmp/*.SimpleFormsApi.metadata.json'].any?).to equal(true)
    ensure
      Common::FileHelpers.delete_file_if_exists(mock_file_path_metadata)
    end
  end

  describe 'upload doc' do
    let(:mock_file) { Common::FileHelpers.random_file_path }
    let(:mock_file_path_pdf) { "#{mock_file}-mock-upload.pdf" }
    let(:mock_file_path_metadata) { "#{mock_file}.SimpleFormsApi.metadata.json" }

    it 'upload doc to mock location' do
      VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
        mock_upload_url = 'https://sandbox-api.va.gov/services_user_content/vba_documents/id-path-doesnt-matter'
        Prawn::Document.new.render_file mock_file_path_pdf
        response = simple_forms_service.upload_doc(upload_url: mock_upload_url,
                                                   file: mock_file_path_pdf,
                                                   metadata: mock_metadata)
        expect(response.status).to equal(200)
      ensure
        Common::FileHelpers.delete_file_if_exists(mock_file_path_pdf)
      end
    end
  end
end
