# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ch31SubmissionsReportMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    context 'with some sample claims', run_at: '2017-07-27 00:00:00' do
      let!(:vre_claim_1) do
        create(:veteran_readiness_employment_claim, updated_at: '2017-07-26 00:00:00 UTC')
      end

      let!(:vre_claim_2) do
        create(:veteran_readiness_employment_claim, updated_at: '2017-07-26 23:59:59 UTC')
      end

      let(:time) { Time.zone.now }

      let(:submitted_claims) do
        SavedClaim::VeteranReadinessEmploymentClaim.where(
          updated_at: (time - 24.hours)..(time - 1.second)
        )
      end

      let(:mail) { described_class.build(submitted_claims).deliver_now }

      before do
        subject.instance_variable_set(:@time, time)
      end

      it 'sends the right email' do
        subject
        text = described_class::REPORT_TEXT
        expect(mail.subject).to eq(text)
        body = File.read('spec/fixtures/vre_claim/ch31_submissions_report.html').gsub(/\n/, "\r\n")
        expect(mail.body.encoded).to eq(body)
      end

      it 'emails the the right staging recipients' do
        subject
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)

        expect(mail.to).to eq(
          %w[
            kcrawford@governmentcio.com
          ]
        )
      end

      it 'emails the the right recipients' do
        subject
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)

        expect(mail.to).to eq(
          %w[
            VRE-CMS.VBAVACO@va.gov
            Jason.Wolf@va.gov
          ]
        )
      end
    end
  end
end
