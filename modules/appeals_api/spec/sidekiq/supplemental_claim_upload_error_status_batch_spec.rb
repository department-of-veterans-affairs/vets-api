# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::SupplementalClaimUploadErrorStatusBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let!(:upload) { create(:supplemental_claim, :status_error) }
  let!(:upload_old) { create(:supplemental_claim, :status_error, created_at: 20.days.ago) }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:in_process_element) do
    [{ uuid: 'ignored',
       status: 'In Process',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  describe '#perform' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:status).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)
      in_process_element[0]['uuid'] = upload.id
      allow(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)
    end

    context 'when status updater is enabled' do
      it 'updates all the statuses' do
        allow(Flipper).to receive(:enabled?).with(:decision_review_sc_status_updater_enabled).and_return(true)
        Sidekiq::Testing.inline! { AppealsApi::SupplementalClaimUploadErrorStatusBatch.new.perform }

        # target upload should be updated with status change
        upload.reload
        expect(upload.status).to eq('processing')
        expect(upload.code).to be_nil
        expect(upload.detail).to be_nil

        # old upload falls outside of batch processor and should not have changed
        upload_old.reload
        expect(upload_old.status).to eq('error')
        expect(upload_old.code).to eq('DOC202')
        expect(upload_old.detail).to eq('Image failed to process')
      end
    end

    context 'when status updater is disabled' do
      it 'does not update statuses' do
        allow(Flipper).to receive(:enabled?).with(:decision_review_sc_status_updater_enabled).and_return(false)
        Sidekiq::Testing.inline! { AppealsApi::SupplementalClaimUploadErrorStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('error')
      end
    end
  end
end
