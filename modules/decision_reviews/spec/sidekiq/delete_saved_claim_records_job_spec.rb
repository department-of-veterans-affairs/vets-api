# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/sidekiq_helper'

RSpec.describe DecisionReviews::DeleteSavedClaimRecordsJob, type: :job do
  subject { described_class }

  let(:delete_date1) { DateTime.new(2024, 1, 1) }
  let(:delete_date2) { DateTime.new(2024, 1, 2) }
  let(:delete_date3) { DateTime.new(2024, 1, 3) }
  let(:delete_date4) { DateTime.new(2024, 1, 4) }
  let(:delete_date5) { DateTime.new(2024, 1, 5) }

  describe 'perform' do
    before do
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
      allow(StatsD).to receive(:increment)
    end

    context 'when the job is disabled via Settings' do
      before do
        allow(Settings.decision_review).to receive(:delete_saved_claim_records_job_enabled).and_return(false)
      end

      it 'does not delete any records and does not increment StatsD' do
        guid = SecureRandom.uuid
        SavedClaim::SupplementalClaim.create(guid:, form: '{}', delete_date: delete_date1)

        Timecop.freeze(delete_date2) do
          subject.new.perform

          expect(SavedClaim.exists?(guid:)).to be true
        end

        expect(StatsD).not_to have_received(:increment)
          .with(start_with('worker.decision_review.delete_saved_claim_records'), any_args)
      end
    end

    context 'when SavedClaim records have a delete_date set' do
      let(:guid1) { SecureRandom.uuid }
      let(:guid2) { SecureRandom.uuid }
      let(:guid3) { SecureRandom.uuid }
      let(:guid4) { SecureRandom.uuid }

      before do
        SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', delete_date: delete_date1)
        SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}', delete_date: delete_date2)
        SavedClaim::HigherLevelReview.create(guid: guid3, form: '{}', delete_date: delete_date3)
        SavedClaim::HigherLevelReview.create(guid: guid4, form: '{}', delete_date: delete_date4)
      end

      it 'deletes only the records with a past or current delete_time' do
        Timecop.freeze(delete_date2) do
          subject.new.perform

          expect(SavedClaim.pluck(:guid)).to contain_exactly(guid3, guid4)
        end

        expect(StatsD).to have_received(:increment)
          .with('worker.decision_review.delete_saved_claim_records.count', 2).exactly(1).time
      end
    end

    context 'when SavedClaim records do not have a delete_date set' do
      let(:guid1) { SecureRandom.uuid }
      let(:guid2) { SecureRandom.uuid }
      let(:guid3) { SecureRandom.uuid }

      before do
        SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}')
        SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}')
        SavedClaim::HigherLevelReview.create(guid: guid3, form: '{}')
      end

      it 'does not delete the records' do
        Timecop.freeze(delete_date4) do
          subject.new.perform

          expect(SavedClaim.pluck(:guid)).to contain_exactly(guid1, guid2, guid3)

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.delete_saved_claim_records.count', 0).exactly(1).time
        end
      end
    end

    context 'when an exception is thrown' do
      let(:error_message) { 'Error message' }

      before do
        allow(SavedClaim).to receive(:where).and_raise(ActiveRecord::ActiveRecordError.new(error_message))
      end

      it 'rescues and logs the exception' do
        expect(Rails.logger).to receive(:error).with('DecisionReviews::DeleteSavedClaimRecordsJob perform exception',
                                                     error_message)

        expect { subject.new.perform }.not_to raise_error

        expect(StatsD).to have_received(:increment)
          .with('worker.decision_review.delete_saved_claim_records.error').exactly(1).time
      end
    end
  end

  describe '#enabled?' do
    subject(:job) { described_class.new }

    context 'when setting is nil' do
      before do
        allow(Settings.decision_review).to receive(:delete_saved_claim_records_job_enabled).and_return(nil)
      end

      it 'returns DEFAULT_ENABLED (true)' do
        expect(job.send(:enabled?)).to be true
      end
    end

    context 'when setting is boolean true' do
      before do
        allow(Settings.decision_review).to receive(:delete_saved_claim_records_job_enabled).and_return(true)
      end

      it 'returns true' do
        expect(job.send(:enabled?)).to be true
      end
    end

    context 'when setting is boolean false' do
      before do
        allow(Settings.decision_review).to receive(:delete_saved_claim_records_job_enabled).and_return(false)
      end

      it 'returns false' do
        expect(job.send(:enabled?)).to be false
      end
    end

    context 'when setting is string "true"' do
      before do
        allow(Settings.decision_review).to receive(:delete_saved_claim_records_job_enabled).and_return('true')
      end

      it 'returns true' do
        expect(job.send(:enabled?)).to be true
      end
    end

    context 'when setting is string "false"' do
      before do
        allow(Settings.decision_review).to receive(:delete_saved_claim_records_job_enabled).and_return('false')
      end

      it 'returns false' do
        expect(job.send(:enabled?)).to be false
      end
    end
  end
end
