# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::NoticeOfDisagreementUploadStatusUpdater, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let(:upload) { create(:notice_of_disagreement, status: 'submitted') }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:in_process_element) do
    [{ uuid: 'ignored',
       status: 'In Process',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  after do
    client_stub { nil }
    faraday_response { nil }
  end

  it_behaves_like 'a monitored worker'

  describe '#perform' do
    it 'updates the status of a NoticeOfDisagreement' do
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      in_process_element[0]['uuid'] = upload.id
      expect(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)

      AppealsApi::NoticeOfDisagreementUploadStatusUpdater.new.perform([upload])
      upload.reload
      expect(upload.status).to eq('processing')
    end
  end
end
