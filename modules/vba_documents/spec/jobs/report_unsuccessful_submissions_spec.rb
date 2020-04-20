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
        consumers = VBADocuments::UploadSubmission.where(created_at: from..to).pluck(:consumer_name).uniq
        expect(VBADocuments::UnsuccessfulReportMailer).to receive(:build).once.with(
          consumers.map do |name|
            c = VBADocuments::UploadSubmission.where(created_at: @from..@to, consumer_name: name).group(:status).count
            totals = c.sum { |_k, v| v }
            {
              name => c.merge(totals: totals,
                              error_rate: "#{(100.0 / totals * c['error']).round}%",
                              expired_rate: "#{(100.0 / totals * c['expired']).round}%")
            }
          end,
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: 'uploaded'
          ).order(:consumer_name),
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: %w[error expired]
          ).order(:consumer_name),
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
