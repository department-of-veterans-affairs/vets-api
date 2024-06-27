# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_reporting_helper'
require_relative 'shared_reporting_examples_spec'

RSpec.describe ClaimsApi::ReportMonthlySubmissions, type: :job do
  subject { described_class.new }

  include_context 'shared reporting defaults'

  shared_examples 'sends mail with expected totals' do
    before { send(claim_setup) }

    let(:from) { 1.month.ago }
    let(:to) { Time.zone.now }

    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        Timecop.freeze

        expect(ClaimsApi::SubmissionReportMailer).to receive(:build).once.with(
          from,
          to,
          consumer_claims_totals: match_array(expected_totals),
          poa_totals: [],
          ews_totals: [],
          itf_totals: []
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)

        subject.perform
        Timecop.return
      end
    end
  end

  context 'with one claims consumer and one PACT claim' do
    let(:claim_setup) { :setup_one_claim_one_pact_claim }
    let(:expected_totals) { [{ 'VA TurboClaim' => { established: 1, totals: 1, pact_count: 1 } }] }

    def setup_one_claim_one_pact_claim
      claim = create(:auto_established_claim, :status_established, cid: '0oa9uf05lgXYk6ZXn297')
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
    end

    it_behaves_like 'sends mail with expected totals'
  end

  context 'with one claims consumer and no PACT claims' do
    let(:claim_setup) { :setup_one_claim_no_pact_claims }
    let(:expected_totals) { [{ 'VA TurboClaim' => { established: 1, totals: 1, pact_count: 0 } }] }

    def setup_one_claim_no_pact_claims
      create(:auto_established_claim, :status_established, cid: '0oa9uf05lgXYk6ZXn297')
    end

    it_behaves_like 'sends mail with expected totals'
  end

  context 'with two claims consumers and one PACT claim' do
    let(:claim_setup) { :setup_two_claims_one_pact_claim }
    let(:expected_totals) do
      [{ 'VA TurboClaim' => { established: 1, totals: 1, pact_count: 1 } },
       { 'VA.gov' => { errored: 1, totals: 1, pact_count: 0 } }]
    end

    def setup_two_claims_one_pact_claim
      claim = create(:auto_established_claim, :status_established, cid: '0oa9uf05lgXYk6ZXn297')
      create(:auto_established_claim, :status_errored, cid: '0oagdm49ygCSJTp8X297')
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
    end

    it_behaves_like 'sends mail with expected totals'
  end

  context 'with one claims consumer and multiple claims' do
    let(:claim_setup) { :setup_one_consumer_multiple_claims }
    let(:expected_totals) { [{ 'VA TurboClaim' => { established: 2, errored: 1, totals: 3, pact_count: 0 } }] }

    def setup_one_consumer_multiple_claims
      cid = '0oa9uf05lgXYk6ZXn297'
      create(:auto_established_claim, :status_established, cid:)
      create(:auto_established_claim, :status_established, cid:)
      create(:auto_established_claim, :status_errored, cid:)
    end

    it_behaves_like 'sends mail with expected totals'
  end

  context 'no claims' do
    let(:claim_setup) { :setup_no_claims }
    let(:expected_totals) { [] }

    def setup_no_claims
      # no claims
    end

    it_behaves_like 'sends mail with expected totals'
  end

  context 'shared reporting behavior' do
    it_behaves_like 'shared reporting behavior'
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Report Monthly Submission Job'
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
