# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/console_utilities'
require './modules/vba_documents/app/models/vba_documents/upload_submission'

RSpec.describe VBADocuments::ConsoleUtilities do
  include VBADocuments::ConsoleUtilities

  context 'When process_manual_status_changes is called' do
    it 'updates the status from success to vbms' do
      upload = VBADocuments::UploadSubmission.new
      upload.update(status: 'success')
      process_manual_status_changes([upload.guid], 'success', 'vbms')
      upload.reload
      expect(upload.status).to eq('vbms')
      expect(upload.metadata['manual_status_change']).to have_key('promoted_at')
      expect(upload.metadata['manual_status_change']['from_status']).to eq('success')
      expect(upload.metadata['manual_status_change']['to_status']).to eq('vbms')
    end

    it 'updates the status from success to error and sets code and detail' do
      error_hash = { 'code' => 'DOC102', 'detail' => 'Duplicate submission' }
      upload = VBADocuments::UploadSubmission.new
      upload.update(status: 'success')
      process_manual_status_changes([upload.guid], 'success', 'error', error_hash)
      upload.reload
      expect(upload.status).to eq('error')
      expect(upload.code).to eq('DOC102')
      expect(upload.detail).to eq('Duplicate submission')
    end

    it 'fails to run with invalid status parameters' do
      upload = VBADocuments::UploadSubmission.new
      upload.update(status: 'success')
      guids = [upload.guid]
      expect { process_manual_status_changes(guids, 'success', 'invalid_status') }.to raise_error do |error|
        expect(error).to be_a(RuntimeError)
        expect(error.message).to eq(VBADocuments::ConsoleUtilities::INVALID_PARAMETERS)
      end
    end

    it 'fails to update the status to error without code and detail passed' do
      upload = VBADocuments::UploadSubmission.new
      upload.update(status: 'success')
      guids = [upload.guid]
      expect { process_manual_status_changes(guids, 'success', 'error') }.to raise_error do |error|
        expect(error).to be_a(RuntimeError)
        expect(error.message).to eq(VBADocuments::ConsoleUtilities::ERROR_STATUS_VALIDATION)
      end
    end
  end
end
# rspec 'modules/vba_documents/spec/lib/console_utilities_spec.rb'
