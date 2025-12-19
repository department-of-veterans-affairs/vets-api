# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/sidekiq_helper'

RSpec.describe DecisionReviews::DeleteSecondaryAppealFormsJob, type: :job do
  subject { described_class }

  let(:delete_date1) { DateTime.new(2024, 1, 1) }
  let(:delete_date2) { DateTime.new(2024, 1, 2) }
  let(:delete_date3) { DateTime.new(2024, 1, 3) }
  let(:delete_date4) { DateTime.new(2024, 1, 4) }
  let(:delete_date5) { DateTime.new(2024, 1, 5) }

  describe 'perform' do
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_secondary_appeal_forms_enabled)
                      .and_return(true)
        allow(StatsD).to receive(:increment)
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
            .with('worker.decision_review.delete_secondary_appeal_forms.count', 2).exactly(1).time
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
              .with('worker.decision_review.delete_secondary_appeal_forms.count', 0).exactly(1).time
          end
        end
      end

      context 'when an exception is thrown' do
        let(:error_message) { 'SecondaryAppealForm deletion error' }

        before do
          allow(SecondaryAppealForm).to receive(:where).and_raise(ActiveRecord::ActiveRecordError.new(error_message))
        end

        it 'rescues and logs the exception' do
          expect(Rails.logger).to receive(:error)
                              .with('DecisionReviews::DeleteSecondaryAppealFormsJob perform exception',
                                    error_message)

          expect { subject.new.perform }.not_to raise_error

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.delete_secondary_appeal_forms.error').exactly(1).time
        end
      end
    end

    context 'when feature flag is disabled' do
      let!(:appeal_submission1) { create(:appeal_submission) }
      let!(:secondary_form1) do
        create(:secondary_appeal_form4142_module, appeal_submission: appeal_submission1, delete_date: delete_date1)
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_delete_secondary_appeal_forms_enabled)
                      .and_return(false)
        allow(StatsD).to receive(:increment)
      end

      it 'does not delete any records even if delete_date is in the past' do
        Timecop.freeze(delete_date4) do
          subject.new.perform

          expect(SecondaryAppealForm.pluck(:guid)).to contain_exactly(secondary_form1.guid)

          expect(StatsD).not_to have_received(:increment)
            .with('worker.decision_review.delete_secondary_appeal_forms.count')
        end
      end
    end
  end
end
