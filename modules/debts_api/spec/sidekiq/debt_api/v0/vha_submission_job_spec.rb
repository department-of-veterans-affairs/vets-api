# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHASubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'successful' do
      before do
        response = { status: 200 }
        allow_any_instance_of(DebtsApi::V0::FinancialStatusReportService)
          .to receive(:submit_vha_fsr).and_return(response)
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
        allow(UserProfileAttributes).to receive(:find).and_return(user_data)
      end

      it 'updates submission on success' do
        described_class.new.perform(form_submission.id, user.uuid)
        expect(form_submission.submitted?).to eq(true)
      end
    end

    context 'failure' do
      before do
        allow_any_instance_of(DebtsApi::V0::FinancialStatusReportService).to receive(:submit_vha_fsr).and_raise('uhoh')
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
        allow(UserProfileAttributes).to receive(:find).and_return(user_data)
      end

      it 'updates submission on error' do
        expect { described_class.new.perform(form_submission.id, user.uuid) }.to raise_exception('uhoh')
        expect(form_submission.failed?).to eq(true)
        expect(form_submission.error_message).to eq('uhoh')
      end
    end
  end
end
