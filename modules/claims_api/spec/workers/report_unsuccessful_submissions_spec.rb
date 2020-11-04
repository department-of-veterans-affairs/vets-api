# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  let(:errored_upload) { FactoryBot.create(:auto_established_claim, :status_errored, source: 'test consumer') }
  let(:pending) { FactoryBot.create(:auto_established_claim, source: 'test consumer') }

  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
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
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        errored_upload
        pending

        job = described_class.new
        job.perform
        totals = job.totals

        expect(totals.first.keys).to eq(['test consumer'])
        expect(totals.first.values.first[:error_rate]).to eq('50%')
      end
    end
  end
end
