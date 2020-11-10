# frozen_string_literal: true

require 'vic/url_helper'
require 'vic/id_card_attribute_error'

module V0
  class IdCardAttributesController < ApplicationController
    before_action :authorize

    def show
      id_attributes = IdCardAttributes.for_user(current_user)
      signed_attributes = ::VIC::URLHelper.generate(id_attributes)
      render json: signed_attributes
    rescue
      raise ::VIC::IDCardAttributeError, status: 502, code: 'VIC011',
                                         detail: 'Could not verify military service attributes'
    end

    private

    def skip_sentry_exception_types
      super + [::VIC::IDCardAttributeError]
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
                       rescue => e
                         log_exception_to_sentry(e)
                         raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::VIC010
      end

      raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::VIC002 if title38_status.blank?

      unless current_user.can_access_id_card?
        raise ::VIC::IDCardAttributeError, ::VIC::IDCardAttributeError::NOT_ELIGIBLE.merge(
          code: "VIC#{title38_status}"
        )
      end
    end
  end
end
