# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportMonthlySubmissions, type: :job do
  subject { described_class.new }

  describe '#perform' do
    let(:from) { 1.month.ago }
    let(:to) { Time.zone.now }

    context 'with counts returned for all the record types' do
      before do
        claim = create(:auto_established_claim, :status_established)
        ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
        create(:auto_established_claim, :status_established)

        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return(double(pluck: %w[claim1 claim_2]))
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: %w[poa_1 poa_2]))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: %w[itf_1 itf_2 otf_3]))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews_1']))
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
            2,
            2,
            3,
            1
          ).and_return(double.tap do |mailer|
                         expect(mailer).to receive(:deliver_now).once
                       end)

          subject.perform
          Timecop.return
        end
      end
    end

    context 'with counts returned for all but ITF' do
      before do
        claim = create(:auto_established_claim, :status_established)
        ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
        create(:auto_established_claim, :status_established)

        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return(double(pluck: %w[claim1 claim_2]))
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: %w[poa_1 poa_2]))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: %w[]))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: ['ews_1']))
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
            2,
            2,
            0,
            1
          ).and_return(double.tap do |mailer|
                         expect(mailer).to receive(:deliver_now).once
                       end)

          subject.perform
          Timecop.return
        end
      end
    end

    context 'with counts returned for all but EWS' do
      before do
        claim = create(:auto_established_claim, :status_established)
        ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'
        create(:auto_established_claim, :status_established)

        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).and_return(double(pluck: %w[claim1 claim_2]))
        allow(ClaimsApi::PowerOfAttorney).to receive(:where).and_return(double(pluck: %w[poa_1 poa_2]))
        allow(ClaimsApi::IntentToFile).to receive(:where).and_return(double(pluck: %w[]))
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:where).and_return(double(pluck: %w[]))
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
            2,
            2,
            0,
            0
          ).and_return(double.tap do |mailer|
                         expect(mailer).to receive(:deliver_now).once
                       end)

          subject.perform
          Timecop.return
        end
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
