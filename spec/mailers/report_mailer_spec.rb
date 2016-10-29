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
  end
end
