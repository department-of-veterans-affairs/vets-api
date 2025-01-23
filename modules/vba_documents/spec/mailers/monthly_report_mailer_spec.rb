# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe VBADocuments::MonthlyReportMailer, type: [:mailer] do
  include VBADocuments::Fixtures

  base_fixture_path = 'reports/monthly_report'

  describe '.build' do
    before do
      prior_twelve_months_stats = []
      12.times do |i|
        reporting_date = (i + 1).months.ago
        prior_twelve_months_stats <<
          build(:monthly_stat, month: reporting_date.month, year: reporting_date.year)
      end

      expect(VBADocuments::Deployment).to receive(:environment).and_return('prod')

      @email = described_class.build(prior_twelve_months_stats).deliver_now
    end

    it 'has an email subject' do
      expect(@email.subject).to eq('Monthly Benefits Intake Submission Report for prod')
    end

    it 'sends the email to the defined recipients' do
      expect(@email.to).to eq(described_class.const_get('RECIPIENTS'))
    end

    it 'has a valid report body' do
      expect(@email.body).to be_a(Mail::Body)
      expect(@email.body.raw_source).to include('Monthly Upload Submission Report (PROD)')
    end
  end

  describe '.fetch_recipients' do
    let(:recipients) { get_fixture_yml("#{base_fixture_path}/report_recipients.yml") }

    context 'when environment is prod and slack alerts are enabled' do
      let(:slack_alert_email) { 'no-reply@example.slack.com' }
      let(:expected_result) do
        [
          'road.runner@va.gov',
          'tweety.bird@va.gov',
          'daffy.duck@va.gov',
          'foghorn.leghorn@va.gov',
          slack_alert_email
        ]
      end

      before do
        expect(VBADocuments::Deployment).to receive(:environment).and_return('prod')
        expect(YAML).to receive(:load_file).and_return(recipients)
      end

      it 'returns the recipients list for prod + all environments + the Slack alert email' do
        with_settings(Settings.vba_documents.slack, enabled: true, default_alert_email: slack_alert_email) do
          expect(described_class.fetch_recipients.sort).to eql(expected_result.sort)
        end
      end
    end

    context 'when environment is staging and slack alerts are not enabled' do
      let(:expected_result) do
        %w[
          road.runner@va.gov
          tweety.bird@va.gov
          bugs.bunny@va.gov
          sylvester.cat@va.gov
        ]
      end

      before do
        expect(VBADocuments::Deployment).to receive(:environment).and_return('staging')
        expect(YAML).to receive(:load_file).and_return(recipients)
      end

      it 'returns the recipients list for staging + all environments' do
        with_settings(Settings.vba_documents.slack, enabled: false) do
          expect(described_class.fetch_recipients.sort).to eql(expected_result.sort)
        end
      end
    end

    context 'when environment is dev and slack alerts are not enabled' do
      let(:expected_result) do
        %w[
          road.runner@va.gov
          tweety.bird@va.gov
        ]
      end

      before do
        expect(VBADocuments::Deployment).to receive(:environment).and_return('dev')
        expect(YAML).to receive(:load_file).and_return(recipients)
      end

      it 'returns the recipients list for dev + all environments' do
        with_settings(Settings.vba_documents.slack, enabled: false) do
          expect(described_class.fetch_recipients.sort).to eql(expected_result.sort)
        end
      end
    end
  end
end
