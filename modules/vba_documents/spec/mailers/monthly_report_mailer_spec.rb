# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe VBADocuments::MonthlyReportMailer, type: [:mailer] do
  include VBADocuments::Fixtures

  monthly_counts = 'monthly_report/monthly_counts.yml'
  summary = 'monthly_report/monthly_summary.yml'
  still_processing = 'monthly_report/still_processing.yml'
  still_success = 'monthly_report/still_success.yml'
  final_monthly_results = 'monthly_report/final_monthly_results.yml'

  before do
    last_month_start = Date.parse('01-03-2021')
    last_month_end = Date.parse('01-04-2021')
    @email = described_class.build(get_fixture_yml(monthly_counts), get_fixture_yml(summary),
                                   get_fixture_yml(still_processing), get_fixture_yml(still_success),
                                   get_fixture_yml(final_monthly_results), last_month_start, last_month_end)
  end

  it 'sends monthly in the subject' do
    expect(@email.subject).to match(/Monthly.*/)
  end
end
