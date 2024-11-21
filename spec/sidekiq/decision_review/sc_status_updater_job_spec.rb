# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'
require 'sidekiq/decision_review/shared_examples_for_status_updater_jobs'

RSpec.describe DecisionReview::ScStatusUpdaterJob, type: :job do
  subject { described_class }

  include_context 'status updater job context', SavedClaim::SupplementalClaim

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_saved_claim_sc_status_updater_job_enabled
      end

      include_examples 'status updater job with base forms', SavedClaim::SupplementalClaim
      include_examples 'status updater job when forms include evidence', SavedClaim::SupplementalClaim
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_saved_claim_sc_status_updater_job_enabled
      end

      it 'does not query SavedClaim::HigherLevelReview records' do
        expect(SavedClaim::SupplementalClaim).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
