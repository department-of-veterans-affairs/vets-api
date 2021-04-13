# frozen_string_literal: true

require 'rails_helper'
require 'date'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe VBADocuments::ReportMonthlySubmissions, type: :job do
  include VBADocuments::Fixtures

  before { Timecop.freeze(Time.zone.parse('2021-04-8 00:00:00 UTC')) }

  after { Timecop.return }

  describe '#perform' do
    monthly_counts = 'monthly_report/monthly_counts.yml'
    summary = 'monthly_report/monthly_summary.yml'
    still_processing = 'monthly_report/still_processing.yml'
    still_success = 'monthly_report/still_success.yml'
    avg_times = 'monthly_report/avg_processing_time.yml'
    final_monthly_results = 'monthly_report/final_monthly_results.yml'
    mode_pages = 'monthly_report/mode.yml' # was monthly_mode_pages with median added
    max_avg_pages = 'monthly_report/max_avg.yml' # was monthly_max_avg_pages.yml

    it 'sends mail' do
      with_settings(Settings.vba_documents, monthly_report: true) do
        last_month_start = Date.parse('01-03-2021')
        last_month_end = Date.parse('01-04-2021')

        monthly_sql = VBADocuments::ReportMonthlySubmissions::MONTHLY_COUNT_SQL
        proc_sql = VBADocuments::ReportMonthlySubmissions::PROCESSING_SQL
        success_sql = VBADocuments::ReportMonthlySubmissions::SUCCESS_SQL
        avg_sql = VBADocuments::ReportMonthlySubmissions::AVG_TIME_TO_VBMS_SQL
        mode_sql = VBADocuments::ReportMonthlySubmissions::MODE_SQL
        median_sql = VBADocuments::ReportMonthlySubmissions::MEDIAN_SQL
        max_avg_pages_sql = VBADocuments::ReportMonthlySubmissions::MAX_AVG_SQL

        job = described_class.new
        allow(job).to receive(:run_sql) do |sql, _args|
          rval = get_fixture_yml(monthly_counts) if sql.eql? monthly_sql
          rval = get_fixture_yml(still_processing) if sql.eql? proc_sql
          rval = get_fixture_yml(still_success) if sql.eql? success_sql
          rval = get_fixture_yml(avg_times) if sql.eql? avg_sql
          rval = get_fixture_yml(mode_pages) if sql.eql? mode_sql
          rval = [{ 'median_pages' => nil, 'median_size' => nil }] if sql.eql? median_sql
          rval = get_fixture_yml(max_avg_pages) if sql.eql? max_avg_pages_sql
          rval
        end

        expect(VBADocuments::MonthlyReportMailer).to receive(:build).once.with(
          get_fixture_yml(monthly_counts), get_fixture_yml(summary), get_fixture_yml(still_processing),
          get_fixture_yml(still_success), get_fixture_yml(final_monthly_results), last_month_start, last_month_end
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        job.perform
      end
    end
  end
end
