# frozen_string_literal: true

require './modules/decision_reviews/spec/support/engine_shared_examples_for_status_updater_jobs'

RSpec.describe DecisionReviews::ScStatusUpdaterJob, type: :job do
  subject { described_class }

  include_context 'engine status updater job context', SavedClaim::SupplementalClaim

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_saved_claim_sc_status_updater_job_enabled
      end

      include_examples 'engine status updater job with base forms', SavedClaim::SupplementalClaim
      include_examples 'engine status updater job when forms include evidence', SavedClaim::SupplementalClaim
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_saved_claim_sc_status_updater_job_enabled
      end

      it 'does not query SavedClaim::SupplementalClaim records' do
        expect(SavedClaim::SupplementalClaim).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
