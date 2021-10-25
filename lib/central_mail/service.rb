# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module CentralMail
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.central_mail'
    include Common::Client::Concerns::Monitoring

    configuration CentralMail::Configuration

    # rubocop:disable Metrics/MethodLength
    def upload(body)
      Raven.extra_context(
        request: {
          metadata: body['metadata']
        }
      )
      body['token'] = Settings.central_mail.upload.token

      response = with_monitoring do
        request(
          :post,
          'upload',
          body
        )
      end

      Raven.extra_context(
        response: {
          status: response.status,
          body: response.body
        }
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.upload.fail") unless response.success?

      response
    end
    # rubocop:enable Metrics/MethodLength

    def status(uuid_or_list)
      body = {
        token: Settings.central_mail.upload.token,
        uuid: [*uuid_or_list].to_json
      }

      request(
        :post,
        'getStatus',
        body
      )
    end

    def self.current_breaker_outage?
      last_cm_outage = Breakers::Outage.find_latest(service: CentralMail::Configuration.instance.breakers_service)
      if last_cm_outage.present? && last_cm_outage.end_time.blank?
        return CentralMail::Service.new.status('').try(:status) != 200
      end

      false
    end
  end
end
