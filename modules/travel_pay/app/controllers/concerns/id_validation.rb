# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module IdValidation
  extend ActiveSupport::Concern

  def validate_uuid_exists!(id, id_type = 'An')
    # NOTE: In request specs, you can’t make params[:claim_id] or params[:id] truly missing because
    # it’s part of the URL path and Rails routing prevents that.
    raise Common::Exceptions::BadRequest.new(detail: "#{id_type} ID is required") if id.blank?

    unless TravelPay::Constants::UUID_REGEX.match?(id)
      raise Common::Exceptions::BadRequest.new(
        detail: "#{id_type} ID is invalid"
      )
    end
  end
end
