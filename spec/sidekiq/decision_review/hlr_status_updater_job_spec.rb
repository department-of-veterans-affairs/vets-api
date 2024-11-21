# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::HlrStatusUpdaterJob, type: :job do
  subject { described_class }

  let(:service) { instance_double(DecisionReviewV1::Service) }

  let(:guid1) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }
  let(:guid3) { SecureRandom.uuid }

  let(:response_complete) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('HLR-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'complete'
    instance_double(Faraday::Response, body: response)
  end

  let(:response_pending) do
    instance_double(Faraday::Response, body: VetsJsonSchema::EXAMPLES.fetch('HLR-SHOW-RESPONSE-200_V2'))
  end

  let(:response_error) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'error'
    instance_double(Faraday::Response, body: response)
  end

  before do
    allow(DecisionReviewV1::Service).to receive(:new).and_return(service)
  end

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_saved_claim_hlr_status_updater_job_enabled
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:error)
      end

      context 'SavedClaim records are present' do
        before do
          SavedClaim::HigherLevelReview.create(guid: guid1, form: '{}')
          SavedClaim::HigherLevelReview.create(guid: guid2, form: '{}')
          SavedClaim::HigherLevelReview.create(guid: guid3, form: '{}', delete_date: DateTime.new(2024, 2, 1).utc)
          SavedClaim::SupplementalClaim.create(form: '{}')
          SavedClaim::NoticeOfDisagreement.create(form: '{}')
        end

        it 'updates SavedClaim::HigherLevelReview delete_date for completed records without a delete_date' do
          expect(service).to receive(:get_higher_level_review).with(guid1).and_return(response_complete)
          expect(service).to receive(:get_higher_level_review).with(guid2).and_return(response_pending)
          expect(service).not_to receive(:get_higher_level_review).with(guid3)

          expect(service).not_to receive(:get_notice_of_disagreement)
          expect(service).not_to receive(:get_supplemental_claim)

          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            claim1 = SavedClaim::HigherLevelReview.find_by(guid: guid1)
            expect(claim1.delete_date).to eq frozen_time + 59.days
            expect(claim1.metadata).to include 'complete'
            expect(claim1.metadata_updated_at).to eq frozen_time

            claim2 = SavedClaim::HigherLevelReview.find_by(guid: guid2)
            expect(claim2.delete_date).to be_nil
            expect(claim2.metadata).to include 'pending'
            expect(claim2.metadata_updated_at).to eq frozen_time

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_hlr_status_updater.processing_records', 2).exactly(1).time
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_hlr_status_updater.delete_date_update').exactly(1).time
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_hlr_status_updater.status', tags: ['status:pending'])
              .exactly(1).time
          end
        end
      end

      context 'SavedClaim record with previous metadata' do
        before do
          allow(Rails.logger).to receive(:info)
        end

        let(:guid4) { SecureRandom.uuid }
        let(:guid5) { SecureRandom.uuid }

        it 'does not increment metrics for unchanged form status or existing final statuses' do
          SavedClaim::HigherLevelReview.create(guid: guid1, form: '{}', metadata: '{"status":"error"}')
          SavedClaim::HigherLevelReview.create(guid: guid2, form: '{}', metadata: '{"status":"submitted"}')
          SavedClaim::HigherLevelReview.create(guid: guid3, form: '{}', metadata: '{"status":"pending"}')
          SavedClaim::HigherLevelReview.create(guid: guid4, form: '{}', metadata: '{"status":"complete"}')
          SavedClaim::HigherLevelReview.create(guid: guid5, form: '{}', metadata: '{"status":"DR_404"}')

          expect(service).not_to receive(:get_higher_level_review).with(guid1)
          expect(service).to receive(:get_higher_level_review).with(guid2).and_return(response_error)
          expect(service).to receive(:get_higher_level_review).with(guid3).and_return(response_pending)
          expect(service).not_to receive(:get_higher_level_review).with(guid4)
          expect(service).not_to receive(:get_higher_level_review).with(guid5)

          subject.new.perform

          claim2 = SavedClaim::HigherLevelReview.find_by(guid: guid2)
          expect(claim2.delete_date).to be_nil
          expect(claim2.metadata).to include 'error'

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_hlr_status_updater.status', tags: ['status:error'])
            .exactly(1).time
          expect(StatsD).not_to have_received(:increment)
            .with('worker.decision_review.saved_claim_hlr_status_updater.status', tags: ['status:pending'])

          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimHlrStatusUpdaterJob form status error', guid: guid1)
          expect(Rails.logger).to have_received(:info)
            .with('DecisionReview::SavedClaimHlrStatusUpdaterJob form status error', guid: guid2)
          expect(StatsD).to have_received(:increment)
            .with('silent_failure', tags: ['service:higher-level-review', 'function: form submission to Lighthouse'])
            .exactly(1).time
        end
      end

      context 'Retrieving SavedClaim records fails' do
        before do
          allow(SavedClaim::HigherLevelReview).to receive(:where).and_raise(ActiveRecord::ConnectionTimeoutError)
          allow(Rails.logger).to receive(:error)
        end

        it 'rescues the error and logs' do
          subject.new.perform

          expect(Rails.logger).to have_received(:error)
            .with('DecisionReview::SavedClaimHlrStatusUpdaterJob error', anything)
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_hlr_status_updater.error').once
        end
      end

      context 'an error occurs while processing' do
        before do
          SavedClaim::HigherLevelReview.create(guid: guid1, form: '{}')

          allow(service).to receive(:get_higher_level_review).and_raise(exception)
        end

        context 'and it is a temporary error' do
          let(:exception) { DecisionReviewV1::ServiceException.new(key: 'DR_504') }

          it 'handles request errors and increments the statsd metric' do
            subject.new.perform

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_hlr_status_updater.error').exactly(1).time
          end
        end

        context 'and it is a 404 error' do
          let(:exception) { DecisionReviewV1::ServiceException.new(key: 'DR_404') }

          it 'updates the status of the record' do
            subject.new.perform

            hlr = SavedClaim::HigherLevelReview.find_by(guid: guid1)
            metadata = JSON.parse(hlr.metadata)
            expect(metadata['status']).to eq 'DR_404'

            expect(Rails.logger).to have_received(:error)
              .with('DecisionReview::SavedClaimHlrStatusUpdaterJob error', { guid: anything, message: anything })
              .exactly(1).time
          end
        end
      end
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_saved_claim_hlr_status_updater_job_enabled
      end

      it 'does not query SavedClaim::HigherLevelReview records' do
        expect(SavedClaim::HigherLevelReview).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
