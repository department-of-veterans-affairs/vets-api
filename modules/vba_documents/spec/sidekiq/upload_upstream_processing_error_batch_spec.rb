# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UploadStatusErrorBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }

  # less than MAX_UPSTREAM_ERROR_AGE_DAYS old with upstream error, job should pick up this record
  let!(:emms_error_upload) { create(:upload_submission, :status_error_upstream) }

  # Old errored record, job should not pick up since it's older than MAX_UPSTREAM_ERROR_AGE_DAYS
  let!(:old_error_upload) do
    create(:upload_submission, :status_error_upstream,
           created_at: (VBADocuments::UploadSubmission::MAX_UPSTREAM_ERROR_AGE_DAYS + 1).days.ago)
  end

  # DOC104 error, error not from Central Mail, job should not pick up
  let!(:error_upload) { create(:upload_submission, :status_error) }

  # No error, job should not pickup
  let!(:no_error_upload) { create(:upload_submission) }

  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:vbms_complete_element) do
    [{ uuid: 'ignored',
       status: 'VBMS Complete',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  describe '#perform' do
    it 'updates the submission with EMMS internal processing error' do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(
        'VBADocuments::UploadSubmission upstream processing error resolved',
        { guid: emms_error_upload.guid, code: 'DOC202',
          detail: 'Upstream status: Errors: ERR-EMMS-FAILED, Corrupted File detected.' }
      )
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).with([emms_error_upload.guid]).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      vbms_complete_element[0]['uuid'] = emms_error_upload.guid
      expect(faraday_response).to receive(:body).at_least(:once).and_return([vbms_complete_element].to_json)

      with_settings(Settings.vba_documents,
                    updater_enabled: true) do
        Sidekiq::Testing.inline! do
          VBADocuments::UploadStatusErrorBatch.new.perform
        end
        emms_error_upload.reload
        expect(emms_error_upload.status).to eql('vbms')
        expect(emms_error_upload.detail).to be_nil
        expect(emms_error_upload.code).to be_nil
      end
    end
  end
end
