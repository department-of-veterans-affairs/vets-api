# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::PollForm526Pdf, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  describe '.perform_async' do
    let(:form526_submission) { create(:form526_submission) }

    context 'when all retries are exhausted' do
      let(:form526_job_status) { create(:form526_job_status, :poll_form526_pdf, form526_submission:, job_id: 1) }

      it 'transitions to the pdf_not_found status' do
        job_params = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }

        subject.within_sidekiq_retries_exhausted_block(job_params) do
          # block is required to use this functionality.
          true
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq 'pdf_not_found'
      end
    end
  end
end
