# frozen_string_literal: true

require 'rails_helper'
require 'date'
require './modules/vba_documents/spec/support/vba_document_fixtures'
require './modules/vba_documents/lib/vba_documents/sql_support'

RSpec.describe VBADocuments::ReportMonthlySubmissions, type: :job do
  include VBADocuments::Fixtures

  before { Timecop.freeze(Time.zone.parse('2021-04-8 00:00:00 UTC')) }

  after { Timecop.return }

  describe '#perform' do
    include VBADocuments::SQLSupport

    base_fixture_path = 'reports/monthly_report'
    monthly_counts = "#{base_fixture_path}/monthly_counts.yml"
    summary = "#{base_fixture_path}/monthly_summary.yml"
    still_processing = "#{base_fixture_path}/still_processing.yml"
    still_success = "#{base_fixture_path}/still_success.yml"
    avg_times = "#{base_fixture_path}/avg_processing_time.yml"
    final_monthly_results = "#{base_fixture_path}/final_monthly_results.yml"
    mode = "#{base_fixture_path}/mode.yml"
    max_avg = "#{base_fixture_path}/max_avg.yml"
    rolling_elapsed_times = "#{base_fixture_path}/rolling_elapsed_times.yml"

    it 'sends mail' do
      with_settings(Settings.vba_documents, monthly_report: true) do
        last_month_start = Date.parse('01-03-2021')
        last_month_end = Date.parse('01-04-2021')

        job = described_class.new
        allow(job).to receive(:run_sql) do |sql, _args|
          rval = get_fixture_yml(monthly_counts) if sql.eql? VBADocuments::SQLSupport::MONTHLY_COUNT_SQL
          rval = get_fixture_yml(still_processing) if sql.eql? VBADocuments::SQLSupport::PROCESSING_SQL
          rval = get_fixture_yml(still_success) if sql.eql? VBADocuments::SQLSupport::SUCCESS_SQL
          rval = get_fixture_yml(avg_times) if sql.eql? VBADocuments::SQLSupport::MONTHLY_GROUP_SQL
          rval = get_fixture_yml(mode) if sql.eql? VBADocuments::SQLSupport::MODE_SQL
          rval = [{ 'median_pages' => nil, 'median_size' => nil }] if sql.eql? VBADocuments::SQLSupport::MEDIAN_SQL
          rval = get_fixture_yml(max_avg) if sql.eql? VBADocuments::SQLSupport::MAX_AVG_SQL
          rval = [{ 'median_secs' => 5 }] if sql.eql? VBADocuments::SQLSupport::MEDIAN_ELAPSED_TIME_SQL
          rval
        end

        allow(job).to receive(:rolling_status_times) do
          get_fixture_yml(rolling_elapsed_times)
        end

        expect(VBADocuments::MonthlyReportMailer).to receive(:build).once.with(
          get_fixture_yml(monthly_counts), get_fixture_yml(summary), get_fixture_yml(still_processing),
          get_fixture_yml(still_success), get_fixture_yml(final_monthly_results),
          get_fixture_yml(rolling_elapsed_times), last_month_start, last_month_end
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        job.perform
      end
    end
  end
end
