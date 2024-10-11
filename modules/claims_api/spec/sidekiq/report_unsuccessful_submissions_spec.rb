# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_reporting_helper'
require_relative 'shared_reporting_examples_spec'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  include_context 'shared reporting defaults'

  describe '#perform' do
    let(:from) { 1.day.ago }
    let(:to) { Time.zone.now }
    let(:cid) { '0oa9uf05lgXYk6ZXn297' }
    let(:unsuccessful_poa_submissions) do
      ClaimsApi::PowerOfAttorney.where(created_at: from..to,
                                       status: 'errored')
                                .order(:cid, :status)
                                .pluck(:cid, :status, :id, :created_at)
    end

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
          unsuccessful_claims_submissions: [],
          unsuccessful_va_gov_claims_submissions: nil,
          poa_totals: [],
          unsuccessful_poa_submissions: [],
          ews_totals: [],
          unsuccessful_evidence_waiver_submissions: [],
          itf_totals: []
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

        expected_issues = "#{((special_issues.to_f / claims_totals[0]['VA TurboClaim'][:totals]) * 100).round(2)}%"
        expected_flash = "#{((flashes.to_f / claims_totals[0]['VA TurboClaim'][:totals]) * 100).round(2)}%"

        expect(claims_totals.first.keys).to eq(['VA TurboClaim'])
        expect(claims_totals[0]['VA TurboClaim'][:percentage_with_flashes]).to eq(expected_flash)
        expect(claims_totals[0]['VA TurboClaim'][:percentage_with_special_issues].to_s).to eq(expected_issues)
      end
    end

    it_behaves_like 'shared reporting behavior'
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Report Unsuccessful Submission Job'
      msg = { 'class' => described_class,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: nil,
          detail: "Job retries exhausted for #{described_class}",
          error: error_msg
        )
      end
    end
  end
end
