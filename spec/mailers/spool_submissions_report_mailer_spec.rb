# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SpoolSubmissionsReportMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    let(:filename) { 'foo' }
    let(:mail) { described_class.build(filename).deliver_now }
    subject do
      stub_reports_s3(filename) do
        mail
      end
    end

    it 'should send the right email' do
      subject
      text = described_class::REPORT_TEXT
      expect(mail.body.encoded).to eq("#{text} (link expires in one week)<br>#{subject}")
      expect(mail.subject).to eq(text)
      expect(mail.to).to eq(['lihan@adhocteam.us'])
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'should email the the right recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            lihan@adhocteam.us
            dana.kuykendall@va.gov
            Jennifer.Waltz2@va.gov
            shay.norton@va.gov
            DONALD.NOBLE2@va.gov
          ]
        )
      end
    end
  end
end
