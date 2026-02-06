# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::SupplementalClaimUploadStatusBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let!(:upload) { create(:supplemental_claim, :status_submitted) }
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
      before { Flipper.enable :decision_review_sc_status_updater_enabled } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'updates all the statuses' do
        Sidekiq::Testing.inline! { AppealsApi::SupplementalClaimUploadStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('processing')
      end
    end

    context 'when status updater is disabled' do
      it 'does not update statuses' do
        Flipper.disable :decision_review_sc_status_updater_enabled # rubocop:disable Project/ForbidFlipperToggleInSpecs
        Sidekiq::Testing.inline! { AppealsApi::SupplementalClaimUploadStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('submitted')
      end
    end
  end
end
