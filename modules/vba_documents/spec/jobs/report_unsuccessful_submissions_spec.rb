# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportUnsuccessfulSubmissions, type: :job do
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error) }

  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.vba_documents,
                    unsuccessful_report_enabled: true) do
        Timecop.freeze
        from = 7.days.ago
        to = Time.zone.now
        expect(VBADocuments::UnsuccessfulReportMailer).to receive(:build).once.with(
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: %w[error expired]
          ),
          7.days.ago,
          Time.zone.now
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end
  end
end
