# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }

    context 'when all retries are exhausted' do
      before do
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
      end

      it 'sets submission to failure' do
        described_class.within_sidekiq_retries_exhausted_block({ 'jid' => 123 }) do
          expect(form_submission).to receive(:register_failure)
        end
      end
    end
  end
end
