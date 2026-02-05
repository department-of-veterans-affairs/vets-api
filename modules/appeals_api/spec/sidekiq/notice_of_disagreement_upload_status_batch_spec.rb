# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::NoticeOfDisagreementUploadStatusBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let!(:upload) { create(:notice_of_disagreement, status: 'submitted') }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:in_process_element) do
    [{ uuid: 'ignored',
       status: cmp_status,
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end
  let(:cmp_status) { 'In Process' }

  after do
    client_stub { nil }
    faraday_response { nil }
  end

  describe '#perform' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:status).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)
      in_process_element[0][:uuid] = upload.id
      allow(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)
    end

    context 'when status updater is enabled' do
      before { Flipper.enable :decision_review_nod_status_updater_enabled } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'updates all the statuses' do
        Sidekiq::Testing.inline! { AppealsApi::NoticeOfDisagreementUploadStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('processing')
      end

      # There was a time where "success" was the final status, then that changed to "complete", so make sure
      # we don't leave any old "success"-es behind.
      context 'success to complete status update' do
        let!(:upload) { create(:notice_of_disagreement, status: 'success') }
        let(:cmp_status) { 'VBMS Complete' }

        it 'updates beyond success status and into complete' do
          Sidekiq::Testing.inline! { AppealsApi::NoticeOfDisagreementUploadStatusBatch.new.perform }
          upload.reload
          expect(upload.status).to eq('complete')
        end
      end
    end

    context 'when status updater is disabled' do
      it 'does not update statuses' do
        Flipper.disable :decision_review_nod_status_updater_enabled # rubocop:disable Project/ForbidFlipperToggleInSpecs
        Sidekiq::Testing.inline! { AppealsApi::NoticeOfDisagreementUploadStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('submitted')
      end
    end
  end
end
