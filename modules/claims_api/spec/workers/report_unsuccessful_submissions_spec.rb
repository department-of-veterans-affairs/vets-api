# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  let(:upload_claims) do
    upload_claims = []
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         source: 'test consumer',
                                         evss_response: nil))
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         source: 'test consumer',
                                         evss_response: 'random string'))
    evss_response_array = [{ 'key' => 'key-here', 'severity' => 'FATAL', 'text' => 'message-here' }]
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         source: 'test consumer',
                                         evss_response: evss_response_array))
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         source: 'test consumer',
                                         evss_response: evss_response_array.to_json))
    upload_claims.push(FactoryBot.create(:auto_established_claim_without_flashes_or_special_issues,
                                         :status_errored,
                                         source: 'test consumer',
                                         evss_response: evss_response_array.to_json))
    upload_claims.push(FactoryBot.create(:auto_established_claim_without_flashes_or_special_issues,
                                         :status_errored,
                                         source: 'test consumer',
                                         evss_response: evss_response_array.to_json))
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
        from = 1.day.ago
        expect(ClaimsApi::UnsuccessfulReportMailer).to receive(:build).once.with(
          from,
          to,
          consumer_claims_totals: [],
          unsuccessful_claims_submissions: ClaimsApi::AutoEstablishedClaim.where(created_at: from..to,
                                                                                 status: 'errored')
                                                                      .order(:source, :status)
                                                                      .pluck(:source, :status, :id),
          poa_totals: { total: 0 },
          unsuccessful_poa_submissions: []
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
        upload_claims.push(pending_claims)
        pending_claims

        special_issues = upload_claims.map { |claim| claim[:special_issues].length.positive? ? 1 : 0 }.sum
        flashes = upload_claims.map { |claim| claim[:flashes].length.positive? ? 1 : 0 }.sum

        report = described_class.new
        report.perform
        claims_totals = report.claims_totals

        expected_issues = "#{((special_issues.to_f / claims_totals[0]['test consumer'][:totals]) * 100).round(2)}%"
        expected_flash = "#{((flashes.to_f / claims_totals[0]['test consumer'][:totals]) * 100).round(2)}%"

        expect(claims_totals.first.keys).to eq(['test consumer'])
        expect(claims_totals[0]['test consumer'][:percentage_with_flashes]).to eq(expected_flash)
        expect(claims_totals[0]['test consumer'][:percentage_with_special_issues].to_s).to eq(expected_issues)
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
