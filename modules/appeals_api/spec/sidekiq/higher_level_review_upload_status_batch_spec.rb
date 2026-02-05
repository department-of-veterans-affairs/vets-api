# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewUploadStatusBatch, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let(:upload) { create(:higher_level_review_v2, status: :submitted) }
  let!(:uploads) { [upload] }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:cmp_status) { 'In Process' }

  describe '#perform' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:status).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)
      response_items = [].tap do |memo|
        uploads.each do |u|
          memo << { uuid: u.id, status: cmp_status, errorMessage: '', lastUpdated: '2018-04-25 00:02:39' }
        end
      end
      allow(faraday_response).to receive(:body).at_least(:once).and_return([response_items].to_json)
    end

    context 'when status updater is enabled' do
      before { Flipper.enable :decision_review_hlr_status_updater_enabled } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'updates all the statuses' do
        Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('processing')
      end

      context 'with HLRv1 records' do
        let(:upload) { create(:higher_level_review_v1, status: 'received') }

        it 'ignores them' do
          Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
          upload.reload
          expect(upload.status).to eq('received')
        end
      end

      context 'with HLRv2 records' do
        let(:upload) { create(:higher_level_review_v2, status: 'pending', created_at: '2021-02-03') }

        it 'updates their status' do
          Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
          upload.reload
          expect(upload.status).to eq('processing')
        end
      end

      context 'with HLRv0 records' do
        let(:upload) { create(:higher_level_review_v0, status: 'pending', created_at: '2021-02-03') }

        it 'updates their status' do
          Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
          upload.reload
          expect(upload.status).to eq('processing')
        end
      end
    end

    context 'when status updater is disabled' do
      it 'does not update statuses' do
        Flipper.disable :decision_review_hlr_status_updater_enabled # rubocop:disable Project/ForbidFlipperToggleInSpecs
        Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
        upload.reload
        expect(upload.status).to eq('submitted')
      end
    end
  end
end
