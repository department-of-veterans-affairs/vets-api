# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module CentralMail
  class Service < Common::Client::Base
    ################################################################
    # If you are not a Lighthouse API team, please do not use      #
    # this module. It has been superceded by the                   #
    # Lighthouse::BenefitsIntake::Service module:                  #
    #                                                              #
    #   https://github.com/department-of-veterans-affairs/vets-api/blob/94f88d1bb55d961e036d6fed3117735d6b9074cd/lib/lighthouse/benefits_intake/service.rb
    #
    # The above-linked module sends submissions to Central Mail    #
    # Processing through the Lighthouse Benefits Intake API        #
    #                                                              #
    # Additionally, it is the responsibility of any team sending   #
    # submissions to Lighthouse to monitor those submissions. See  #
    # here for more details:                                       #
    #                                                              #
    # https://depo-platform-documentation.scrollhelp.site/developer-docs/endpoint-monitoring
    ################################################################

    STATSD_KEY_PREFIX = 'api.central_mail'
    include Common::Client::Concerns::Monitoring

    configuration CentralMail::Configuration

    # rubocop:disable Metrics/MethodLength
    def upload(body)
      Sentry.set_extras(
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

      Sentry.set_extras(
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

    def self.service_is_up?
      last_cm_outage = Breakers::Outage.find_latest(service: CentralMail::Configuration.instance.breakers_service)
      last_cm_outage.blank? || last_cm_outage.end_time.present?
    end
  end
end
