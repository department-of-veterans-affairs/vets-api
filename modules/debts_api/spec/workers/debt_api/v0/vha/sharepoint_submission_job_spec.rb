# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }

    context 'failure' do
      before do
        sp_stub = instance_double(DebtManagementCenter::Sharepoint::Request)
        allow(DebtManagementCenter::Sharepoint::Request).to receive(:new).and_return(sp_stub)
        allow(sp_stub).to receive(:upload).and_raise('Server Error')
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
      end

      it 'sets submission to failure' do
        expect { described_class.new.perform(form_submission.id) }.to raise_exception('Server Error')
        expect(form_submission.failed?).to eq(true)
        expect(form_submission.error_message).to eq('SharePoint Submission Failed: Server Error.')
      end
    end
  end
end
