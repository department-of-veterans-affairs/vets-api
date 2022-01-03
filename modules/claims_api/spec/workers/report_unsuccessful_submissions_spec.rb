# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  let(:errored_upload_claims) do
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
  let(:pending_claims) { FactoryBot.create(:auto_established_claim, source: 'test consumer') }
  let(:poa_submissions) { FactoryBot.create(:power_of_attorney) }
  let(:errored_poa_submissions) do
    FactoryBot.create(:power_of_attorney, :errored)
    FactoryBot.create(
      :power_of_attorney,
      :errored,
      vbms_error_message: 'File could not be retrieved from AWS'
    )
  end

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
          consumer_claims_totals: [],
          flash_statistics: [],
          special_issues_statistics: [],
          pending_claims_submissions: ClaimsApi::AutoEstablishedClaim.where(created_at: from..to,
                                                                            status: 'pending')
                                                                .order(:source, :status)
                                                                .pluck(:source, :status, :id),
          unsuccessful_claims_submissions: ClaimsApi::AutoEstablishedClaim.where(created_at: from..to,
                                                                                 status: 'errored')
                                                                      .order(:source, :status)
                                                                      .pluck(:source, :status, :id),
          grouped_claims_errors: [],
          grouped_claims_warnings: [],
          poa_totals: { total: 0 },
          unsuccessful_poa_submissions: []
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
        errored_upload_claims

        job = described_class.new
        job.perform
        grouped_claims_errors = job.claims_errors_hash[:uniq_errors]

        expect(grouped_claims_errors.count).to eq(1)
      end
    end

    it 'calculate totals' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        errored_upload_claims
        pending_claims

        job = described_class.new
        job.perform
        claims_totals = job.claims_totals

        expect(claims_totals.first.keys).to eq(['test consumer'])
        expect(claims_totals.first.values.first[:error_rate]).to eq('80%')
      end
    end

    it 'includes POA metrics' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        poa_submissions
        errored_poa_submissions

        job = described_class.new
        job.perform

        poa_totals = job.poa_totals
        unsuccessful_poa_submissions = job.unsuccessful_poa_submissions

        expect(poa_totals.count).to eq(3)
        expect(unsuccessful_poa_submissions.count).to eq(2)
      end
    end
  end
end
