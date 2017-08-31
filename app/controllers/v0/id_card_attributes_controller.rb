# frozen_string_literal: true
require 'vic_helper'

module V0
  class IdCardAttributesController < ApplicationController
    before_action :authorize

    def show
      id_attributes = IdCardAttributes.for_user(current_user)
      vic_url = VIC::Helper.generate_url(id_attributes)
      redirect_to vic_url
    rescue => e
      # TODO: tighten this up
      raise Common::Exceptions::Forbidden, detail: 'Could not verify military service attributes'
    end

    private

    def authorize
      raise Common::Exceptions::Forbidden unless current_user.loa3?
      # TODO: possible change to more specific exceptions with actionable codes
      raise Common::Exceptions::Forbidden, detail: 'Unable to verify EDIPI' unless current_user.edipi.present?
      # TODO: enable after local testing
      begin
        raise Common::Exceptions::Forbidden, detail: 'Not eligible for a Veteran ID Card' unless current_user.veteran?
      rescue => e
        log_exception_to_sentry(e)
        raise Common::Exceptions::Forbidden, detail: 'Could not verify Veteran status'
      end
    end
  end
end
