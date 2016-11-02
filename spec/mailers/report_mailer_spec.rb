# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ReportMailer, type: [:mailer, :aws_helpers] do
  describe '#year_to_date_report_email' do
    let(:filename) { 'foo' }
    let(:mail) { described_class.year_to_date_report_email(filename).deliver_now }
    subject do
      stub_reports_s3(filename) do
        mail
      end
    end

    it 'should send the right email' do
      subject
      text = described_class::YEAR_TO_DATE_REPORT_TEXT
      expect(mail.body.encoded).to eq("#{text} (link expires in one week)<br>#{subject}")
      expect(mail.subject).to eq(text)
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'should email the va stakeholders' do
        subject
        expect(mail.to).to eq(
          ['Christopher.Marino2@va.gov',
           '224A.VBACO@va.gov',
           'rodney.alexander@va.gov',
           'URSULA.BRITT@va.gov',
           'Carolyn.McCollam@va.gov',
           'shay.norton@va.gov',
           'Christina.DiTucci@va.gov']
        )

        expect(mail.cc).to eq(
          ['robert.orifici@va.gov',
           'Erin.Haskins@va.gov',
           'Shante.Kinzie@va.gov',
           'Brandye.Terrell@va.gov',
           'michele.mendola@va.gov',
           'Schnell.Carraway@va.gov',
           'Danita.Johnson@va.gov',
           'jude.lopez1@va.gov',
           'Steven.Wayland@va.gov']
        )
      end
    end
  end
end
