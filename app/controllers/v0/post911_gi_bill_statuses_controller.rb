# frozen_string_literal: true

require 'evss/gi_bill_status/external_service_unavailable'
require 'evss/gi_bill_status/gi_bill_status_response'
require 'evss/gi_bill_status/outside_working_hours'
require 'evss/gi_bill_status/service'
require 'formatters/date_formatter'

module V0
  class Post911GIBillStatusesController < ApplicationController
    include IgnoreNotFound
    include SentryLogging

    before_action { authorize :evss, :access? }
    before_action :service_available?, only: :show

    STATSD_GI_BILL_TOTAL_KEY = 'api.evss.gi_bill_status.total'
    STATSD_GI_BILL_FAIL_KEY = 'api.evss.gi_bill_status.fail'

    def show
      response = service.get_gi_bill_status
      if response.success?
        render json: response,
               serializer: Post911GIBillStatusSerializer,
               meta: response.metadata
      else
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ["error:#{response.error_type}"])
        render_error_json(response)
      end
    ensure
      StatsD.increment(STATSD_GI_BILL_TOTAL_KEY)
    end

    private

    def render_error_json(response)
      error_type = response.error_type
      case error_type
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:evss_error]
        # 503
        raise EVSS::GiBillStatus::ExternalServiceUnavailable
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:vet_not_found]
        log_vet_not_found(@current_user, response.timestamp)
        raise Common::Exceptions::RecordNotFound, @current_user.common_name
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:invalid_auth]
        # 403
        raise Common::Exceptions::UnexpectedForbidden, detail: 'Missing correlation id'
      else
        # 500
        raise Common::Exceptions::InternalServerError
      end
    end

    def service_available?
      unless EVSS::GiBillStatus::Service.within_scheduled_uptime?
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:scheduled_downtime'])
        headers['Retry-After'] = EVSS::GiBillStatus::Service.retry_after_time
        # 503 response
        raise EVSS::GiBillStatus::OutsideWorkingHours
      end
    end

    def log_vet_not_found(user, timestamp)
      PersonalInformationLog.create(
        data: { timestamp:, user: user_json(user) },
        error_class: 'EVSS::GiBillStatus::NotFound'
      )
    end

    def user_json(user)
      {
        first_name: user.first_name,
        last_name: user.last_name,
        assurance_level: user.loa[:current].to_s,
        birls_id: user.birls_id,
        icn: user.icn,
        edipi: user.edipi,
        mhv_correlation_id: user.mhv_correlation_id,
        participant_id: user.participant_id,
        vet360_id: user.vet360_id,
        ssn: user.ssn,
        birth_date: Formatters::DateFormatter.format_date(user.birth_date, :datetime_iso8601)
      }.to_json
    end

    def skip_sentry_exception_types
      super + [EVSS::GiBillStatus::OutsideWorkingHours]
    end

    def service
      EVSS::GiBillStatus::Service.new(@current_user)
    end
  end
end
