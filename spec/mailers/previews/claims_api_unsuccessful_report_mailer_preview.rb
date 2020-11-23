# frozen_string_literal: true

class ClaimsApiUnsuccessfulReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = Time.at(0).utc

    ClaimsApi::UnsuccessfulReportMailer.build(from, to, consumer_totals: totals,
                                                        pending_submissions: pending,
                                                        unsuccessful_submissions: errored,
                                                        flash_statistics: flash_statistics)
  end

  private

  def errored
    [
      ClaimsApi::AutoEstablishedClaim.new(id: 'valid-id-here',
                                          source: 'GDIT',
                                          status: 'errored',
                                          evss_response: nil,
                                          created_at: Time.at(0).utc,
                                          updated_at: Time.zone.now)
    ]
  end

  def pending
    []
  end

  def flash_statistics
    [
      { flash: 'POW', count: 1, percentage: '50.0%' },
      { flash: 'Homeless', count: 1, percentage: '50.0%' },
      { flash: 'Terminally Ill', count: 1, percentage: '50.0%' }
    ]
  end

  def totals
    [
      { 'GDIT' => { pending: 2,
                    totals: 2,
                    error_rate: '0%',
                    percentage_with_flashes: '50.0%' } }
    ]
  end
end
