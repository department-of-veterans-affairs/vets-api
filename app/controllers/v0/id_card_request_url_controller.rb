# frozen_string_literal: true
require 'vic/url_helper'
require 'vic/id_card_attribute_error'

module V0
  class IdCardRequestUrlController < ApplicationController
    before_action :authorize

    def show
      id_attributes = IdCardAttributes.for_user(current_user)
      vic_url = VIC::URLHelper.generate_url(id_attributes)
      render json: { 'redirect' => vic_url }
    rescue => e
      # Catch all potential errors looking up military service history
      # Monitor sentry to make sure this is not catching more general errors
      log_exception_to_sentry(e)
      raise VIC::IDCardAttributeError, status: 502, code: 'VIC011',
                                       detail: 'Could not verify military service attributes'
    end

    private

    def authorize
      # TODO: Clean up this method, particularly around need to blanket rescue from
      # VeteranStatus method
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to ID card attributes' unless
        current_user.loa3?
      raise VIC::IDCardAttributeError, status: 403, code: 'VIC002', detail: 'Unable to verify EDIPI' unless
        current_user.edipi.present?
      begin
        unless current_user.veteran?
          raise VIC::IDCardAttributeError, status: 403, code: 'VIC003',
                                           detail: 'Not eligible for a Veteran ID Card'
        end
      rescue => e
        # current_user.veteran? above may raise an error if user was not found or backend service was unavailable
        log_exception_to_sentry(e)
        raise VIC::IDCardAttributeError, status: 403, code: 'VIC010',
                                         detail: 'Could not verify Veteran status'
      end
    end
  end
end
