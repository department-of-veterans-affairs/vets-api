# frozen_string_literal: true

require 'rails_helper'

RSpec.describe YearToDateReportMailer, type: %i[mailer aws_helpers] do
  describe '#year_to_date_report_email' do
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
            lihan@adhocteam.us
            Delli-Gatti_Michael@bah.com
            sonntag_adam@bah.com
          ]
        )
      end
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the va stakeholders' do
        subject
        expect(mail.to).to eq(
          %w[
            Christopher.Marino2@va.gov
            224B.VBAVACO@va.gov
            Carolyn.McCollam@va.gov
            shay.norton@va.gov
            Christina.DiTucci@va.gov
            Brandye.Terrell@va.gov
            michele.mendola@va.gov
            Christopher.Sutherland@va.gov
            John.McNeal@va.gov
            Anne.kainic@va.gov
            ian@adhocteam.us
            Brandon.Scott2@va.gov
            224C.VBAVACO@va.gov
            peter.chou1@va.gov
            Joseph.Welton@va.gov
            222A.VBAVACO@va.gov
            Ricardo.DaSilva@va.gov
            peter.nastasi@va.gov
            Lucas.Tickner@va.gov
            kyle.pietrosanto@va.gov
            robert.shinners@va.gov
            johnny@oddball.io
            John.Holton2@va.gov
          ]
        )
      end
    end
  end
end
