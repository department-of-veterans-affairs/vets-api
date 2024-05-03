# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api_submission/service'

describe SimpleFormsApi::PdfUploader do
  describe '#upload_to_benefits_intake' do
    it 'returns the status and uuid from Lighthouse' do
      file_path = '/some-path'
      metadata = { 'meta' => 'data' }
      form_id = '12-3456'
      expected_status = 200
      expected_uuid = 'some-uuid'
      lighthouse_service = double
      upload_location = double
      body = { 'data' => { 'id' => expected_uuid } }
      params = { form_number: form_id }
      expected_response = double(status: expected_status)
      allow(upload_location).to receive(:body).and_return body
      allow(lighthouse_service).to receive(:get_upload_location).and_return upload_location
      allow(lighthouse_service).to receive(:upload_doc).and_return expected_response
      allow(SimpleFormsApiSubmission::Service).to receive(:new).and_return lighthouse_service

      pdf_uploader = SimpleFormsApi::PdfUploader.new(file_path, metadata, form_id)

      expect(pdf_uploader.upload_to_benefits_intake(params)).to eq [expected_status, expected_uuid]
    end
  end
end
