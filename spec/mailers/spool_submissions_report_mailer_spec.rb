# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SpoolSubmissionsReportMailer, type: [:mailer, :aws_helpers] do
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
  end
end
