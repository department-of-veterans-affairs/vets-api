# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportUnsuccessfulSubmissions, type: :job do
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error) }

  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.vba_documents,
                    unsuccessful_report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        expect(VBADocuments::UnsuccessfulReportMailer).to receive(:build).once.with(
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: %w[error expired]
          ),
          from,
          to
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end
  end
end
