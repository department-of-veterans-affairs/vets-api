# frozen_string_literal: true

class ClaimsApiUnsuccessfulReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = Time.at(0).utc

    ClaimsApi::UnsuccessfulReportMailer.build(
      from,
      to,
      consumer_claims_totals: claims_totals,
      pending_claims_submissions: pending_claims,
      unsuccessful_claims_submissions: unsuccessful_claims_submissions,
      grouped_claims_errors: uniq_claims_errors,
      grouped_claims_warnings: uniq_claims_warnings,
      flash_statistics: flash_statistics,
      special_issues_statistics: special_issues_statistics,
      poa_totals: poa_totals,
      unsuccessful_poa_submissions: unsuccessful_poa_submissions
    )
  end

  private

  def unsuccessful_claims_submissions
    [
      { id: '019be853-fd70-4b65-b37b-c3f3842aaaca', status: 'errored', source: 'GDIT' }
    ]
  end

  def pending_claims
    [
      { id: '6ceaa096-0d6d-4f23-a587-04ef359cee4a', status: 'pending', source: 'GDIT' },
      { id: 'b8c5c06c-e3ae-4ad1-b8da-b2d1b028e6bf', status: 'pending', source: 'GDIT' }
    ]
  end

  def uniq_claims_errors
    [
      { code: { 'key' => 'key-here', 'severity' => 'FATAL', 'text' => 'message-here' }, count: 2, percentage: '0%' },
      { code: { 'key' => 'key-here', 'severity' => 'ERROR', 'text' => 'message-here' }, count: 1, percentage: '0%' }
    ]
  end

  def uniq_claims_warnings
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

  def special_issues_statistics
    [
      { code: 'ALS', count: 1, percentage: '50.0%' },
      { code: 'PTSD/2', count: 1, percentage: '50.0%' }
    ]
  end

  def claims_totals
    [
      { 'GDIT' => { pending: 2,
                    errored: 1,
                    totals: 3,
                    error_rate: '33%',
                    percentage_with_flashes: '50.0%',
                    percentage_with_special_issues: '50.0%' } }
    ]
  end

  def poa_totals
    { total: 24, updated: 15, errored: 2, pending: 3, uploaded: 4 }
  end

  def unsuccessful_poa_submissions
    [
      { id: 'd9e04d01-366e-445f-809c-b2af46a226db', created_at: 7.days.ago.to_s,
        vbms_error_message: 'File could not be retrieved from AWS' },
      { id: 'b1744635-25de-4adb-b64c-37436c1e4079', created_at: 6.days.ago.to_s,
        vbms_error_message: 'File could not be retrieved from AWS' },
      { id: '69d521f9-0879-40c5-ad43-27a38e462592', created_at: 5.days.ago.to_s,
        vbms_error_message: 'An unknown error has occurred when uploading document' },
      { id: 'c313a69c-60ab-4f53-af9f-1f003f67058f', created_at: 4.days.ago.to_s,
        vbms_error_message: 'An unknown error has occurred when uploading document' }
    ]
  end
end
