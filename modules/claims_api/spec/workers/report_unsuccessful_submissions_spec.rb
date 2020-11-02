# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  let(:error_upload) { FactoryBot.create(:auto_established, :status_errored, consumer_name: 'test consumer') }
  let(:pending) { FactoryBot.create(:auto_established, :status_uploaded, consumer_name: 'test consumer') }

  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.claims,
                    unsuccessful_report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        expect(ClaimsApi::UnsuccessfulReportMailer).to receive(:build).once.with(
          [],
          ClaimsApi::AutoEstablishedClaim.where(
            created_at: from..to,
            status: 'pending'
          ).order(:source, :status),
          ClaimsApi::AutoEstablishedClaim.where(
            created_at: from..to,
            status: 'errored'
          ).order(:source, :status),
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
      with_settings(Settings.claims,
                    unsuccessful_report_enabled: true) do
        error_upload
        upload
        expired

        job = described_class.new
        job.perform
        totals = job.totals

        expect(totals.first.keys).to eq(['test consumer'])
        expect(totals.first.values.first[:error_rate]).to eq('33%')
      end
    end
  end
end
