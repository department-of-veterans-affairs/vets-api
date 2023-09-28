# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::VBSSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'failure' do
      before do
        allow_any_instance_of(DebtsApi::V0::FinancialStatusReportService)
          .to receive(:submit_to_vbs).and_raise('Server Error')
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
        allow(UserProfileAttributes).to receive(:find).and_return(user_data)
      end

      it 'sets submission to failure' do
        expect { described_class.new.perform(form_submission.id, user.uuid) }.to raise_exception('Server Error')
        expect(form_submission.failed?).to eq(true)
        expect(form_submission.error_message).to eq('VBS Submission Failed: Server Error.')
      end
    end
  end
end
