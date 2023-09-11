# frozen_string_literal: true

require 'rails_helper'

require 'debt_management_center/sharepoint/request'

RSpec.describe Form5655::VBA::DmcSubmissionJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:form_submission) { create(:form5655_submission) }

    it 'uploads to the SharePoint repository' do
      job = described_class.new
      expect_any_instance_of(DebtManagementCenter::FinancialStatusReportService).to receive(:submit_vba_fsr).with(
        form_submission.form
      )
      job.perform(form_submission.id)
    end
  end
end
