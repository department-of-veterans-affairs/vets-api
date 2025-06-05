# frozen_string_literal: true

require './modules/decision_reviews/spec/support/engine_shared_examples_for_status_updater_jobs'

RSpec.describe DecisionReviews::NodStatusUpdaterJob, type: :job do
  subject { described_class }

  include_context 'engine status updater job context', SavedClaim::NoticeOfDisagreement

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_saved_claim_nod_status_updater_job_enabled)
                                            .and_return(true)
      end

      include_examples 'engine status updater job with base forms', SavedClaim::NoticeOfDisagreement
      include_examples 'engine status updater job when forms include evidence', SavedClaim::NoticeOfDisagreement
    end

    context 'with flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_saved_claim_nod_status_updater_job_enabled)
                                            .and_return(false)
      end

      it 'does not query SavedClaim::HigherLevelReview records' do
        expect(SavedClaim::NoticeOfDisagreement).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
