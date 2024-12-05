# frozen_string_literal: true

require 'formatters/date_formatter'
require 'lighthouse/benefits_education/service'
require 'post911_sob/dgib/client'
require 'dgi/claimant/service'

module V1
  class Post911GIBillStatusesController < ApplicationController
    include IgnoreNotFound
    include SentryLogging
    service_tag 'gibill-statement'

    STATSD_GI_BILL_TOTAL_KEY = 'api.lighthouse.gi_bill_status.total'
    STATSD_GI_BILL_FAIL_KEY = 'api.lighthouse.gi_bill_status.fail'

    BENEFIT_TYPE = 'Chapter33'

    def show
      lighthouse_response = lighthouse_service.get_gi_bill_status
      dgib_response = dgib_service.get_entitlement_transferred_out if Flipper.enabled?(:sob_updated_design)
      render json: Post911GIBillStatusSerializer.new(lighthouse_response, dgib_response)
    rescue Breakers::OutageException => e
      raise e
    rescue => e
      byebug
      handle_error(e)
    ensure
      StatsD.increment(STATSD_GI_BILL_TOTAL_KEY)
    end

    private

    def handle_error(e)
      # TO-DO: Update error handling for DGIB claimant service
      status = e.errors.first[:status].to_i
      log_vet_not_found(@current_user, Time.now.in_time_zone('Eastern Time (US & Canada)')) if status == 404
      StatsD.increment(STATSD_GI_BILL_FAIL_KEY, tags: ["error:#{status}"])
      render json: { errors: e.errors }, status: status || :internal_server_error
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

    def lighthouse_service
      BenefitsEducation::Service.new('1012667122V019349')
    end

    def dgib_service
      Post911SOB::DGIB::Client.new(claimant_id)
    end

    def claimant_id
      meb_api_service.get_claimant_info(BENEFIT_TYPE)
    end

    def meb_api_service
      MebApi::DGI::Claimant::Service.new(@current_user)
    end
  end
end
