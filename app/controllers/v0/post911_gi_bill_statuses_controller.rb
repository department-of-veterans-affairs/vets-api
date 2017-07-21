# frozen_string_literal: true
module V0
  class Post911GIBillStatusesController < ApplicationController
    include SentryLogging

    STATSD_GI_BILL_TOTAL_KEY = 'api.evss.gi_bill_status.total'
    STATSD_GI_BILL_FAIL_KEY = 'api.evss.gi_bill_status.fail'

    def show
      response = service.get_gi_bill_status
      if response.contains_education_info?
        # 200
        render json: response,
               serializer: Post911GIBillStatusSerializer,
               meta: response.metadata
      elsif response.evss_error?
        # 503
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:evss_error'])
        raise EVSS::GiBillStatus::ServiceException
      elsif response.vet_not_found?
        # 404
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:vet_not_found'])
        raise Common::Exceptions::RecordNotFound, @current_user.email
      elsif response.timeout?
        # 504
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:timeout'])
        raise Common::Exceptions::GatewayTimeout
      elsif response.invalid_auth?
        # 403
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:invalid_auth'])
        raise Common::Exceptions::Forbidden, detail: 'Missing correlation id'
      else
        # 500
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:unknown'])
        log_message_to_sentry('Unexpected EVSS GiBillStatus Response', :error, response.to_h)
        raise Common::Exceptions::InternalServerError
      end
    ensure
      StatsD.increment(STATSD_GI_BILL_TOTAL_KEY)
    end

    private

    def service
      EVSS::GiBillStatus::ServiceFactory.get_service(
        user: @current_user, mock_service: Settings.evss.mock_gi_bill_status
      )
    end
  end
end
