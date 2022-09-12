# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportUnsuccessfulSubmissions, type: :job do
  let(:expired_hash) do
    { guid: '8ef145ee-3c6a-4215-b39a-af56c0d2c347', status: 'expired', consumer_name: 'test consumer' }
  end
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error, consumer_name: 'test consumer') }
  let(:expired) { FactoryBot.create(:upload_submission, expired_hash) }
  let(:upload) { FactoryBot.create(:upload_submission, :status_uploaded, consumer_name: 'test consumer') }

  describe '#perform' do
    xit 'sends mail' do
      with_settings(Settings.vba_documents,
                    report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        expect(VBADocuments::UnsuccessfulReportMailer).to receive(:build).once.with(
          send_mail_totals,
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

    xit 'calculate totals' do
      with_settings(Settings.vba_documents,
                    report_enabled: true) do
        error_upload
        upload
        expired

        job = described_class.new
        job.perform
        totals = job.totals

        expect(totals.keys.first).to eq('test consumer')
        expect(totals['test consumer'][:error_rate]).to eq('33%')
        expect(totals['test consumer'][:expired_rate]).to eq('33%')
      end
    end
  end

  private

  def send_mail_totals
    {
      'summary' => {
        'pending' => 0,
        'uploaded' => 0,
        'received' => 0,
        'processing' => 0,
        'success' => 0,
        'vbms' => 0,
        'error' => 0,
        'expired' => 0,
        'total' => 0,
        'success_rate' => '0%',
        'error_rate' => '0%',
        'expired_rate' => '0%'
      }
    }
  end
end
