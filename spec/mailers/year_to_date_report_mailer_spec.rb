# frozen_string_literal: true

require 'rails_helper'

RSpec.describe YearToDateReportMailer, type: %i[mailer aws_helpers] do
  describe '#year_to_date_report_email' do
    let(:filename) { 'foo' }
    let(:mail) { described_class.build(filename).deliver_now }
    subject do
      stub_reports_s3(filename) do
        mail
      end
    end

    context 'when sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
      end
      it 'should send the right email' do
        subject
        text = described_class::REPORT_TEXT
        expect(mail.body.encoded).to eq("#{text} (link expires in one week)<br>#{subject}")
        expect(mail.subject).to eq(text)
      end
      it 'should email the the right staging recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            lihan@adhocteam.us
            akulkarni@meetveracity.com
            Hoffmaster_David@bah.com
            Turner_Desiree@bah.com
            Delli-Gatti_Michael@bah.com
            Walter_Jenny@bah.com
            Brandon.Scott2@va.gov
            224C.VBAVACO@va.gov
            peter.chou1@va.gov
            Joseph.Welton@va.gov
            222A.VBAVACO@va.gov
          ]
        )
      end
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'should email the va stakeholders' do
        subject
        expect(mail.to).to eq(
          %w[
            Christopher.Marino2@va.gov
            224B.VBAVACO@va.gov
            rodney.alexander@va.gov
            Carolyn.McCollam@va.gov
            shay.norton@va.gov
            Christina.DiTucci@va.gov
            Brandye.Terrell@va.gov
            michele.mendola@va.gov
            jude.lopez1@va.gov
            Christopher.Sutherland@va.gov
            John.McNeal@va.gov
            Anne.kainic@va.gov
            ian@adhocteam.us
            dan.hoicowitz.va@gmail.com
            Darla.VanNieukerk@va.gov
            Walter_Jenny@bah.com
            Hoffmaster_David@bah.com
            akulkarni@meetveracity.com
            Brandon.Scott2@va.gov
            224C.VBAVACO@va.gov
            peter.chou1@va.gov
            Joseph.Welton@va.gov
            222A.VBAVACO@va.gov
          ]
        )
      end
    end
  end
end
