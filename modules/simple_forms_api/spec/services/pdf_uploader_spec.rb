# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
# require 'simple_forms_api_submission/service'

describe SimpleFormsApi::PdfUploader do
  describe '#upload_to_benefits_intake' do
    it 'returns the status and uuid from Lighthouse',
       skip: 'we plan to refactor away from SimpleFormsApiSubmission::Service' do
      file_path = '/some-path'
      metadata = { 'meta' => 'data' }
      form_id = '12-3456'
      expected_status = 200
      expected_uuid = 'some-uuid'
      lighthouse_service = double
      upload_location = double
      form = double
      body = { 'data' => { 'id' => expected_uuid } }
      params = { form_number: form_id }
      expected_response = double(status: expected_status)
      allow(upload_location).to receive(:body).and_return body
      allow(lighthouse_service).to receive_messages(get_upload_location: upload_location, upload_doc: expected_response)
      allow(SimpleFormsApiSubmission::Service).to receive(:new).and_return lighthouse_service

      pdf_uploader = SimpleFormsApi::PdfUploader.new(file_path, metadata, form)

      expect(pdf_uploader.upload_to_benefits_intake(params)).to eq [expected_status, expected_uuid]
    end
  end
end
