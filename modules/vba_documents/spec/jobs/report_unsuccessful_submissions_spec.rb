# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportUnsuccessfulSubmissions, type: :job do
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error, consumer_name: 'test consumer') }
  let(:upload) { FactoryBot.create(:upload_submission, :status_uploaded, consumer_name: 'test consumer') }
  let(:expired) { FactoryBot.create(:upload_submission, status: 'expired', consumer_name: 'test consumer') }

  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.vba_documents,
                    unsuccessful_report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        expect(VBADocuments::UnsuccessfulReportMailer).to receive(:build).once.with(
          [],
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: 'uploaded'
          ).order(:consumer_name, :status),
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: %w[error expired]
          ).order(:consumer_name, :status),
          from,
          to
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end

    it 'calculate totals' do
      with_settings(Settings.vba_documents,
                    unsuccessful_report_enabled: true) do
        error_upload
        upload
        expired

        job = described_class.new
        job.perform
        totals = job.totals

        expect(totals.first.keys).to eq(['test consumer'])
        expect(totals.first.values.first[:error_rate]).to eq('33%')
        expect(totals.first.values.first[:expired_rate]).to eq('33%')
      end
    end
  end
end
