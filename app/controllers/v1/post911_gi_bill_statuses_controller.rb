# frozen_string_literal: true

require 'formatters/date_formatter'
require 'lighthouse/benefits_education/outside_working_hours'
require 'lighthouse/benefits_education/service'

module V1
  class Post911GIBillStatusesController < ApplicationController
    include IgnoreNotFound
    include SentryLogging
    service_tag 'gibill-statement'

    
    # TO-DO: Remove this action after transition of LTS to 24/7 availability
    before_action :service_available?, only: :show

    STATSD_GI_BILL_TOTAL_KEY = 'api.lighthouse.gi_bill_status.total'
    STATSD_GI_BILL_FAIL_KEY = 'api.lighthouse.gi_bill_status.fail'

    def show
      response = service.get_gi_bill_status
      render json: Post911GIBillStatusSerializer.new(response)
    rescue Breakers::OutageException => e
      raise e
    rescue => e
      handle_error(e)
    ensure
      StatsD.increment(STATSD_GI_BILL_TOTAL_KEY)
    end

    private

    def handle_error(e)
      status = e.errors.first[:status].to_i
      log_vet_not_found(@current_user, Time.now.in_time_zone('Eastern Time (US & Canada)')) if status == 404
      StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ["error:#{status}"])
      render json: { errors: e.errors }, status: status || :internal_server_error
    end

    # TO-DO: Remove this method after transition of LTS to 24/7 availability
    def service_available?
      unless Flipper.enabled?(:sob_updated_design) || BenefitsEducation::Service.within_scheduled_uptime?
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
      BenefitsEducation::Service.new('1012667122V019349')
    end
  end
end
