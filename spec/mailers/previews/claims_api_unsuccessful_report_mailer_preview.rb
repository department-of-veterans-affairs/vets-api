# frozen_string_literal: true

class ClaimsApiUnsuccessfulReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = Time.at(0).utc

    ClaimsApi::UnsuccessfulReportMailer.build(from, to, consumer_totals: totals,
                                                        pending_submissions: pending,
                                                        unsuccessful_submissions: unsuccessful_submissions,
                                                        grouped_errors: uniq_errors,
                                                        grouped_warnings: uniq_warnings,
                                                        flash_statistics: flash_statistics,
                                                        special_issues_statistics: si_statistics)
  end

  private

  def unsuccessful_submissions
    [
      { id: '019be853-fd70-4b65-b37b-c3f3842aaaca', status: 'errored', source: 'GDIT' }
    ]
  end

  def pending
    [
      { id: '6ceaa096-0d6d-4f23-a587-04ef359cee4a', status: 'pending', source: 'GDIT' },
      { id: 'b8c5c06c-e3ae-4ad1-b8da-b2d1b028e6bf', status: 'pending', source: 'GDIT' }
    ]
  end

  def uniq_errors
    [
      { code: { 'key' => 'key-here', 'severity' => 'FATAL', 'text' => 'message-here' }, count: 2, percentage: '0%' },
      { code: { 'key' => 'key-here', 'severity' => 'ERROR', 'text' => 'message-here' }, count: 1, percentage: '0%' }
    ]
  end

  def uniq_warnings
    [
      { code: { 'key' => 'key-here', 'severity' => 'WARNING', 'text' => 'message-here' }, count: 2, percentage: '0%' }
    ]
  end

  def flash_statistics
    [
      { code: 'POW', count: 1, percentage: '50.0%' },
      { code: 'Homeless', count: 1, percentage: '50.0%' },
      { code: 'Terminally Ill', count: 1, percentage: '50.0%' }
    ]
  end

  def si_statistics
    [
      { code: 'ALS', count: 1, percentage: '50.0%' },
      { code: 'PTSD/2', count: 1, percentage: '50.0%' }
    ]
  end

  def totals
    [
      { 'GDIT' => { pending: 2,
                    errored: 1,
                    totals: 3,
                    error_rate: '33%',
                    percentage_with_flashes: '50.0%',
                    percentage_with_special_issues: '50.0%' } }
    ]
  end
end
