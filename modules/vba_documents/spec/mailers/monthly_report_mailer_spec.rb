# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe VBADocuments::MonthlyReportMailer, type: [:mailer] do
  include VBADocuments::Fixtures

  base_fixture_path = 'reports/monthly_report'
  monthly_counts = "#{base_fixture_path}/monthly_counts.yml"
  summary = "#{base_fixture_path}/monthly_summary.yml"
  still_processing = "#{base_fixture_path}/still_processing.yml"
  still_success = "#{base_fixture_path}/still_success.yml"
  final_monthly_results = "#{base_fixture_path}/final_monthly_results.yml"
  rolling_elapsed_times = "#{base_fixture_path}/rolling_elapsed_times.yml"

  before do
    last_month_start = Date.parse('01-03-2021')
    last_month_end = Date.parse('01-04-2021')
    @email = described_class.build(get_fixture_yml(monthly_counts), get_fixture_yml(summary),
                                   get_fixture_yml(still_processing), get_fixture_yml(still_success),
                                   get_fixture_yml(final_monthly_results), get_fixture_yml(rolling_elapsed_times),
                                   last_month_start, last_month_end)
  end

  it 'sends monthly in the subject' do
    expect(@email.subject).to match(/Monthly.*/)
  end

  describe '.fetch_recipients' do
    let(:recipients) { get_fixture_yml("#{base_fixture_path}/report_recipients.yml") }
    let(:slack_alert_email) { Settings.vba_documents.slack.default_alert_email }

    context 'when environment is prod' do
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
        allow(Settings.vba_documents.slack).to receive(:enabled).and_return(true)
      end

      it 'returns the recipients list for prod + all environments + the Slack alert email' do
        expect(described_class.fetch_recipients.sort).to eql(expected_result.sort)
      end
    end

    context 'when environment is staging' do
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
        allow(Settings.vba_documents.slack).to receive(:enabled).and_return(false)
      end

      it 'returns the recipients list for staging + all environments' do
        expect(described_class.fetch_recipients.sort).to eql(expected_result.sort)
      end
    end

    context 'when environment is dev' do
      let(:expected_result) do
        %w[
          road.runner@va.gov
          tweety.bird@va.gov
        ]
      end

      before do
        expect(VBADocuments::Deployment).to receive(:environment).and_return('dev')
        expect(YAML).to receive(:load_file).and_return(recipients)
        allow(Settings.vba_documents.slack).to receive(:enabled).and_return(false)
      end

      it 'returns the recipients list for all environments only' do
        expect(described_class.fetch_recipients.sort).to eql(expected_result.sort)
      end
    end
  end
end
