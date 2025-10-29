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
    context 'when feature flags are enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_saved_claims_job_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_secondary_appeal_forms_enabled).and_return(true)
        allow(StatsD).to receive(:increment)
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

      context 'when SecondaryAppealForm records have a delete_date set' do
        let!(:appeal_submission1) { create(:appeal_submission) }
        let!(:appeal_submission2) { create(:appeal_submission) }
        let!(:appeal_submission3) { create(:appeal_submission) }
        let!(:appeal_submission4) { create(:appeal_submission) }

        let!(:secondary_form1) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission1, delete_date: delete_date1)
        end
        let!(:secondary_form2) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission2, delete_date: delete_date2)
        end
        let!(:secondary_form3) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission3, delete_date: delete_date3)
        end
        let!(:secondary_form4) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission4, delete_date: delete_date4)
        end

        it 'deletes only the SecondaryAppealForm records with a past or current delete_time' do
          Timecop.freeze(delete_date2) do
            subject.new.perform

            expect(SecondaryAppealForm.pluck(:guid)).to contain_exactly(secondary_form3.guid, secondary_form4.guid)
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.delete_saved_claim_records.count', 0).exactly(1).time
        end
      end

      context 'when SecondaryAppealForm records do not have a delete_date set' do
        let!(:appeal_submission1) { create(:appeal_submission) }
        let!(:appeal_submission2) { create(:appeal_submission) }
        let!(:appeal_submission3) { create(:appeal_submission) }

        let!(:secondary_form1) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission1, delete_date: nil)
        end
        let!(:secondary_form2) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission2, delete_date: nil)
        end
        let!(:secondary_form3) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission3, delete_date: nil)
        end

        it 'does not delete the SecondaryAppealForm records' do
          Timecop.freeze(delete_date4) do
            subject.new.perform

            expect(SecondaryAppealForm.pluck(:guid)).to contain_exactly(
              secondary_form1.guid, secondary_form2.guid, secondary_form3.guid
            )

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.delete_saved_claim_records.count', 0).exactly(1).time
          end
        end
      end

      context 'when both SavedClaim and SecondaryAppealForm records have delete_dates' do
        let(:guid1) { SecureRandom.uuid }
        let!(:secondary_form2) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission2, delete_date: delete_date3)
        end
        let!(:secondary_form1) do
          create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission1, delete_date: delete_date1)
        end
        let(:guid2) { SecureRandom.uuid }
        let!(:appeal_submission1) { create(:appeal_submission) }
        let!(:appeal_submission2) { create(:appeal_submission) }

        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', delete_date: delete_date1)
          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}', delete_date: delete_date3)
        end


        it 'deletes both record types with past or current delete_times' do
          Timecop.freeze(delete_date2) do
            subject.new.perform

            expect(SavedClaim.pluck(:guid)).to contain_exactly(guid2)
            expect(SecondaryAppealForm.pluck(:guid)).to contain_exactly(secondary_form2.guid)
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.delete_saved_claim_records.count', 1).exactly(1).time
        end

        it 'logs the deletion counts for both record types' do
          expect(Rails.logger).to receive(:info).with(
            'DecisionReviews::DeleteSavedClaimRecordsJob completed successfully',
            hash_including(
              saved_claims_deleted: 1,
              secondary_forms_deleted: 1,
              secondary_forms_deletion_enabled: true,
              total_deleted: 2
            )
          )

          Timecop.freeze(delete_date2) do
            subject.new.perform
          end
        end
      end

      context 'when an exception is thrown during SavedClaim deletion' do
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

      context 'when an exception is thrown during SecondaryAppealForm deletion' do
        let(:guid1) { SecureRandom.uuid }
        let(:error_message) { 'SecondaryAppealForm deletion error' }

        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', delete_date: delete_date1)
          allow(SecondaryAppealForm).to receive(:where).and_raise(ActiveRecord::ActiveRecordError.new(error_message))
        end

        it 'rescues and logs the exception, but SavedClaim deletion should have succeeded' do
          expect(Rails.logger).to receive(:error).with('DecisionReviews::DeleteSavedClaimRecordsJob perform exception',
                                                       error_message)

          Timecop.freeze(delete_date2) do
            expect { subject.new.perform }.not_to raise_error

            # SavedClaim should have been deleted before the SecondaryAppealForm error
            expect(SavedClaim.pluck(:guid)).to be_empty
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.delete_saved_claim_records.error').exactly(1).time
        end
      end
    end

    context 'when main feature flag is disabled' do
      let(:guid1) { SecureRandom.uuid }
      let(:guid2) { SecureRandom.uuid }

      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_saved_claims_job_enabled).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_secondary_appeal_forms_enabled).and_return(true)
        allow(StatsD).to receive(:increment)

        SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', delete_date: delete_date1)
        SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}')
      end

      it 'does not delete any records even if delete_date is in the past' do
        Timecop.freeze(delete_date4) do
          subject.new.perform

          expect(SavedClaim.pluck(:guid)).to contain_exactly(guid1, guid2)

          expect(StatsD).not_to have_received(:increment)
            .with('worker.decision_review.delete_saved_claim_records.count')
        end
      end
    end

    context 'when secondary forms deletion feature flag is disabled' do
      let(:guid1) { SecureRandom.uuid }
      let!(:appeal_submission1) { create(:appeal_submission) }
      let!(:secondary_form1) do
        create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission1, delete_date: delete_date1)
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_saved_claims_job_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_secondary_appeal_forms_enabled).and_return(false)
        allow(StatsD).to receive(:increment)

        SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', delete_date: delete_date1)
      end

      it 'deletes SavedClaim records but not SecondaryAppealForm records' do
        Timecop.freeze(delete_date2) do
          subject.new.perform

          expect(SavedClaim.pluck(:guid)).to be_empty
          expect(SecondaryAppealForm.pluck(:guid)).to contain_exactly(secondary_form1.guid)

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.delete_saved_claim_records.count', 1).exactly(1).time
        end
      end

      it 'logs that secondary forms deletion is disabled' do
        expect(Rails.logger).to receive(:info).with(
          'DecisionReviews::DeleteSavedClaimRecordsJob completed successfully',
          hash_including(
            saved_claims_deleted: 1,
            secondary_forms_deleted: 0,
            secondary_forms_deletion_enabled: false,
            total_deleted: 1
          )
        )

        Timecop.freeze(delete_date2) do
          subject.new.perform
        end
      end
    end
  end
end
