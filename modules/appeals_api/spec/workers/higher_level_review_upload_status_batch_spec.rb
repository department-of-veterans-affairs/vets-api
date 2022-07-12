# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewUploadStatusBatch, type: :job do
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:upload) { create(:higher_level_review_v2, status: :submitted) }
  let!(:uploads) { [upload] }
  let(:faraday_response) { instance_double('Faraday::Response') }
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
      it 'updates all the statuses' do
        with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
          Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
          upload.reload
          expect(upload.status).to eq('processing')
        end
      end

      context 'with HLRv1 records' do
        let(:upload) { create(:higher_level_review_v1, status: 'received') }

        it 'ignores them' do
          with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            upload.reload
            expect(upload.status).to eq('received')
          end
        end
      end

      context 'with HLRv2 records' do
        let(:upload) { create(:higher_level_review_v2, status: 'pending', created_at: '2021-02-03') }

        it 'updates their status' do
          with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            upload.reload
            expect(upload.status).to eq('processing')
          end
        end
      end

      context 'throttling flag' do
        let!(:uploads) { create_list :higher_level_review_v2, 12, status: :submitted }
        let(:cmp_status) { 'Complete' }

        before do
          stub_const("#{described_class}::THROTTLED_OLDEST_LIMIT", 5)
          stub_const("#{described_class}::THROTTLED_NEWEST_LIMIT", 5)
        end

        context 'is enabled' do
          before { Flipper.enable :decision_review_hlr_status_update_throttling }

          it 'only updates a limited number of records each run' do
            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            tally = AppealsApi::HigherLevelReview.all.pluck(:status).tally
            expect(tally['complete']).to eq 10
            expect(tally['submitted']).to eq 2

            # Run again and ensure we pick up the remaining that were skipped by throttling
            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            tally = AppealsApi::HigherLevelReview.all.pluck(:status).tally
            expect(tally['complete']).to eq 12
          end

          it 'logs a warning when throttling has caught up to current records' do
            allow(Rails.logger).to receive(:warn)
            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            expect(Rails.logger).not_to have_received(:warn)

            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            expect(Rails.logger).to have_received(:warn).with(
              'AppealsApi::HigherLevelReviewUploadStatusBatch::ThrottleWarning',
              'throttle_limit' => 5,
              'actual_count' => 2
            )
          end
        end

        context 'is disabled' do
          before { Flipper.disable :decision_review_hlr_status_update_throttling }

          it 'updates all records each run' do
            Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
            tally = AppealsApi::HigherLevelReview.all.pluck(:status).tally
            expect(tally['complete']).to eq 12
          end
        end
      end
    end

    context 'when status updater is disabled' do
      it 'does not update statuses' do
        with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: false) do
          Sidekiq::Testing.inline! { AppealsApi::HigherLevelReviewUploadStatusBatch.new.perform }
          upload.reload
          expect(upload.status).to eq('submitted')
        end
      end
    end
  end
end
