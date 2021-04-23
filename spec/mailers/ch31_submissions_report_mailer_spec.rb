# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ch31SubmissionsReportMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    subject do
      stub_reports_s3(filename) do
        mail
      end
    end

    let(:filename) { 'foo' }
    let(:mail) { described_class.build(filename).deliver_now }

    context 'when sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
      end

      it 'sends the right email' do
        subject
        text = described_class::REPORT_TEXT
        expect(mail.body.encoded).to eq("#{text} (link expires in one week)<br>#{subject}")
        expect(mail.subject).to eq(text)
      end

      it 'emails the the right staging recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            kcrawford@governmentcio.com
          ]
        )
      end
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the the right recipients' do
        subject

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
