# frozen_string_literal: true
require 'evss/gi_bill_status/gi_bill_status_response'

module V0
  class Post911GIBillStatusesController < ApplicationController
    include SentryLogging

    STATSD_GI_BILL_TOTAL_KEY = 'api.evss.gi_bill_status.total'
    STATSD_GI_BILL_FAIL_KEY = 'api.evss.gi_bill_status.fail'

    def show
      response = service.get_gi_bill_status
      if response.success?
        render json: response,
               serializer: Post911GIBillStatusSerializer,
               meta: response.metadata
      else
        error_type = response.error_type
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ["error:#{error_type}"])
        render_error_json(error_type)
      end
    ensure
      StatsD.increment(STATSD_GI_BILL_TOTAL_KEY)
    end

    private

    def render_error_json(error_type)
      case error_type
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:evss_error]
        # 503
        raise EVSS::GiBillStatus::ServiceException
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:vet_not_found]
        begin
          GibsNotFoundUser.log(@current_user)
        ensure
          raise Common::Exceptions::RecordNotFound, @current_user.email
        end
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:timeout]
        # 504
        raise Common::Exceptions::GatewayTimeout
      when EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS[:invalid_auth]
        # 403
        raise Common::Exceptions::UnexpectedForbidden, detail: 'Missing correlation id'
      else
        # 500
        log_message_to_sentry('Unexpected EVSS GiBillStatus Response', :error, response.to_h)
        raise Common::Exceptions::InternalServerError
      end
    end

    def service
      @service ||= EVSS::GiBillStatus::Service.new(
        EVSS::AuthHeaders.new(@current_user).to_h,
        Settings.evss.mock_gi_bill_status
      )
    end
  end
end
