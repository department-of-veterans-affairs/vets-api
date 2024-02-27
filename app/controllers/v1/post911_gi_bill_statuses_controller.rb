# frozen_string_literal: true

require 'formatters/date_formatter'

module V1
  class Post911GIBillStatusesController < ApplicationController
    include IgnoreNotFound
    include SentryLogging
    service_tag 'gibill-statement'

    before_action :service_available?, only: :show

    STATSD_GI_BILL_TOTAL_KEY = 'api.lighthouse.gi_bill_status.total'
    STATSD_GI_BILL_FAIL_KEY = 'api.lighthouse.gi_bill_status.fail'

    def show
      begin
        response = service.get_gi_bill_status
        render json: response,
              serializer: Post911GIBillStatusSerializer,
              meta: response.metadata
      rescue StandardError => e
        status = e.errors.first[:status].to_i if e.errors&.first&.key?(:status)
        if status == 404 
          log_vet_not_found(@current_user, Time.now)
        end
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ["error:#{status}"])
        render json: { error: e.errors.first }, status: status || :internal_server_error
      ensure
        StatsD.increment(STATSD_GI_BILL_TOTAL_KEY)
      end
    end

    private

    def service_available?
      unless BenefitsEducation::Service.within_scheduled_uptime?
        StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ['error:scheduled_downtime'])
        headers['Retry-After'] = BenefitsEducation::Service.retry_after_time
        # 503 response
        raise BenefitsEducation::OutsideWorkingHours
      end
    end

    def log_vet_not_found(user, timestamp)
      PersonalInformationLog.create(
        data: { timestamp:, user: user_json(user) },
        error_class: 'BenefitsEducation::NotFound'
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
      super + [BenefitsEducation::OutsideWorkingHours]
    end

    def service
      BenefitsEducation::Service.new(@current_user&.icn)
    end
  end
end
