# frozen_string_literal: true

require 'form1010_ezr/service'
require 'hca/enrollment_eligibility/service'

module V0
  class Form1010EzrsController < ApplicationController
    service_tag 'health-information-update'

    before_action :record_submission_attempt, only: :create

    def create
      parsed_form = parse_form(params[:form])

      result = Form1010Ezr::Service.new(@current_user).submit_form(parsed_form)

      clear_saved_form('10-10EZR')

      render(json: result)
    end

    def veteran_prefill_data
      render(json: HCA::EnrollmentEligibility::Service.new.get_ezr_data(current_user.icn))
    end

    private

    def record_submission_attempt
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.submission_attempt")
    end

    def parse_form(form)
      JSON.parse(form)
    end
  end
end
