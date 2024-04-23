# frozen_string_literal: true

class LoadAverageDaysForClaimCompletionJob
  include Sidekiq::Job

  # this will go away once the file publishing is setup.
  def connection
    @conn ||= Faraday.new('https://www.va.gov/') do |faraday|
      faraday.use      :breakers
      faraday.use      Faraday::Response::RaiseError

      faraday.request :json

      faraday.response :json, content_type: /\bjson/
      faraday.adapter Faraday.default_adapter
    end
  end

  AVERAGE_DAYS_REGEX = /([0-9]{1,3}(\.[0-9]{1,2})) days/

  def load_average_days
    rtn = connection.get('/disability/after-you-file-claim/').body
    matches = AVERAGE_DAYS_REGEX.match(rtn)
    if matches.present? && matches.length >= 1
      rec = AverageDaysForClaimCompletion.new
      rec.average_days = matches[1].to_f
      rec.save!
    else
      logger.error('Unable to load average days, possibly the page has changed and the regex no longer matches!')
    end
  rescue Faraday::ClientError => e
    logger.error("Unable to load average days: #{e.message}")
  end

  def perform
    logger.info('Beginning: LoadAverageDaysForClaimCompletionJob')
    load_average_days
    logger.info('Completing: LoadAverageDaysForClaimCompletionJob')
  end
end
