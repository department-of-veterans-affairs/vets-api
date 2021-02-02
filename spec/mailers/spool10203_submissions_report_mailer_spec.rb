# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spool10203SubmissionsReportMailer, type: %i[mailer aws_helpers] do
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
            Brian.Grubb@va.gov
            Joseph.Preisser@va.gov
            Lucas.Tickner@va.gov
            tammy.hurley1@va.gov
            Ricardo.DaSilva@va.gov
            kyle.pietrosanto@va.gov
            lihan@adhocteam.us
            Delli-Gatti_Michael@bah.com
            Darrell.Neel@va.gov
            Neel_Darrell@bah.com
            shawkey_daniel@bah.com
            sonntag_adam@bah.com
            Turner_Desiree@bah.com
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
            Brian.Grubb@va.gov
            Joseph.Preisser@va.gov
            Lucas.Tickner@va.gov
            tammy.hurley1@va.gov
            Ricardo.DaSilva@va.gov
            kyle.pietrosanto@va.gov
            Joshua.Lashbrook@va.gov
            shay.norton@va.gov
            dana.kuykendall@va.gov
            Jennifer.Waltz2@va.gov
            kathleen.dalfonso@va.gov
            lihan@adhocteam.us
          ]
        )
      end
    end
  end
end
