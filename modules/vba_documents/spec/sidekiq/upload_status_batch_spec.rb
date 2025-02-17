# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UploadStatusBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let!(:upload) { create(:upload_submission, :status_received) }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:in_process_element) do
    [{ uuid: 'ignored',
       status: 'In Process',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  describe '#perform' do
    it 'updates all the statuses' do
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      in_process_element[0]['uuid'] = upload.guid
      expect(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)

      with_settings(Settings.vba_documents,
                    updater_enabled: true) do
        Sidekiq::Testing.inline! do
          VBADocuments::UploadStatusBatch.new.perform
        end
        upload.reload
        expect(upload.status).to eq('processing')
      end
    end
  end
end
