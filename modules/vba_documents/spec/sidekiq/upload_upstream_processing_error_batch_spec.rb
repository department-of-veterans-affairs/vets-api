# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UploadUpstreamProcessingErrorBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }

  # test target, less than 14 days old in emms error status, job should pick up this record
  let!(:emms_error_upload) { create(:upload_submission, :status_emms_error) }

  # Old errored record, job should not pick up since it's older than 14 days
  let!(:old_error_upload) { create(:upload_submission, :status_emms_error, created_at: 20.days.ago) }

  # DOC104 error, error not from EMMS, job should not pick up
  let!(:error_upload) { create(:upload_submission, :status_error) }

  # No error, job should not pickup
  let!(:no_error_upload) { create(:upload_submission) }

  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:in_process_element) do
    [{ uuid: 'ignored',
       status: 'VBMS Complete',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  describe '#perform' do
    it 'updates the submission with EMMS internal processing error' do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(
        'VBADocuments::UploadSubmission EMMS processing error resolved',
        { guid: emms_error_upload.guid, code: "DOC202", detail: "image failed to process" })
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).with([emms_error_upload.guid]).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      in_process_element[0]['uuid'] = emms_error_upload.guid
      expect(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)

      with_settings(Settings.vba_documents,
                    updater_enabled: true) do
        Sidekiq::Testing.inline! do
          VBADocuments::UploadUpstreamProcessingErrorBatch.new.perform
        end
        emms_error_upload.reload
        expect(emms_error_upload.status).to eq('vbms')
        expect(emms_error_upload.detail).to eq(nil)
        expect(emms_error_upload.code).to eq(nil)

      end
    end
  end
end
