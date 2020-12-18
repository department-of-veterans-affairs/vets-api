# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  let(:errored_upload) do
    FactoryBot.create(:auto_established_claim,
                      :status_errored,
                      source: 'test consumer',
                      evss_response: nil)
    FactoryBot.create(:auto_established_claim,
                      :status_errored,
                      source: 'test consumer',
                      evss_response: 'random string')

    evss_response_array = [{ 'key' => 'key-here', 'severity' => 'FATAL', 'text' => 'message-here' }]
    FactoryBot.create(:auto_established_claim,
                      :status_errored,
                      source: 'test consumer',
                      evss_response: evss_response_array)
    FactoryBot.create(:auto_established_claim,
                      :status_errored,
                      source: 'test consumer',
                      evss_response: evss_response_array.to_json)
  end
  let(:pending) { FactoryBot.create(:auto_established_claim, source: 'test consumer') }

  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        expect(ClaimsApi::UnsuccessfulReportMailer).to receive(:build).once.with(
          from,
          to,
          consumer_totals: [],
          flash_statistics: [],
          pending_submissions: ClaimsApi::AutoEstablishedClaim.where(created_at: from..to,
                                                                     status: 'pending').order(:source, :status),
          unsuccessful_submissions: ClaimsApi::AutoEstablishedClaim.where(created_at: from..to,
                                                                          status: 'errored').order(:source, :status)
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end

    it 'group errors' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        errored_upload

        job = described_class.new
        job.perform
        grouped_errors = job.errored_grouped

        expect(grouped_errors.count).to eq(3)
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
        expect(totals.first.values.first[:error_rate]).to eq('80%')
      end
    end
  end
end
