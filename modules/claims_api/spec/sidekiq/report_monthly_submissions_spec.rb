# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_reporting_helper'
require_relative 'shared_reporting_examples_spec'

RSpec.describe ClaimsApi::ReportMonthlySubmissions, type: :job do
  subject { described_class.new }

  include_context 'shared reporting defaults'

  describe '#perform' do
    let(:from) { 1.month.ago }
    let(:to) { Time.zone.now }

    before do
      claim = create(:auto_established_claim, :status_established, cid: '0oa9uf05lgXYk6ZXn297')
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
    end

    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        Timecop.freeze
        pact_act_data = ClaimsApi::ClaimSubmission.where(created_at: from..to)

        expect(ClaimsApi::SubmissionReportMailer).to receive(:build).once.with(
          from,
          to,
          pact_act_data,
          consumer_claims_totals: monthly_claims_totals,
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

  # Expected value based on what is created in the before
  def monthly_claims_totals
    [
      { 'VA TurboClaim' => { established: 1, totals: 1.0 } }
    ]
  end
end
