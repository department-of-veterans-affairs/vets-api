# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportMonthlySubmissions, type: :job do
  subject { described_class.new }

  describe '#perform' do
    let(:from) { 1.month.ago }
    let(:to) { Time.zone.now }

    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        Timecop.freeze
        pact_act_data = []

        expect(ClaimsApi::SubmissionReportMailer).to receive(:build).once.with(
          from,
          to,
          pact_act_data,
          consumer_claims_totals: [],
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
