# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ReportMailer, type: :mailer do
  describe '#year_to_date_report_email' do
    subject { described_class.year_to_date_report_email('foo').deliver_now }

    it 'should send the right email' do
      text = 'Year to date report'
      expect(subject.body.encoded).to eq(text)
      expect(subject.subject).to eq(text)
    end
  end
end
