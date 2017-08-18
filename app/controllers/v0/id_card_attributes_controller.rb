# frozen_string_literal: true
require 'vic_helper'

module V0
  class IdCardAttributesController < ApplicationController
    before_action :authorize

    def show
      begin
        id_attributes = IdCardAttributes.for_user(current_user)
        vic_url = VIC::Helper.generate_url(id_attributes)
        redirect_to vic_url
      rescue => e
        # TODO tighten this up
        raise Common::Exceptions::InternalServerError(e)
      end
    end

    private

    def authorize
      raise Common::Exceptions::Forbidden unless current_user.loa3?
      # TODO possible change to more specific exceptions with actionable codes
      raise Common::Exceptions::Forbidden unless current_user.edipi.present?
      # TODO enable after local testing
      #raise Common::Exceptions::Forbidden, detail: 'Not eligible for a Veteran ID Card' unless current_user.veteran?
    end
  end
end
