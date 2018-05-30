# frozen_string_literal: true

require 'vic/url_helper'
require 'vic/id_card_attribute_error'

module V0
  class IdCardAttributesController < ApplicationController
    before_action :authorize
    before_action(:tag_rainbows)

    def show
      id_attributes = IdCardAttributes.for_user(current_user)
      signed_attributes = ::VIC::URLHelper.generate(id_attributes)
      render json: signed_attributes
    rescue StandardError => e
      log_exception_to_sentry(e)
      raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::VIC002
    end

    private

    def skip_sentry_exception_types
      super + [Common::Exceptions::Forbidden, ::VIC::IDCardAttributeError]
    end

    def authorize
      # TODO: Clean up this method, particularly around need to blanket rescue from
      # VeteranStatus method
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to ID card attributes' unless
        current_user.loa3?
      raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::VIC002 if current_user.edipi.blank?

      title38_status = begin
        current_user.veteran_status.title38_status
      rescue EMISRedis::VeteranStatus::RecordNotFound
        nil
      rescue StandardError => e
        log_exception_to_sentry(e)
        raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::VIC010
      end

      raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::VIC002 if title38_status.blank?
      raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::NOT_ELIGIBLE.merge(
        code: "VIC#{title38_status}"
      ) unless current_user.can_access_id_card?
    end
  end
end
