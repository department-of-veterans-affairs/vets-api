# frozen_string_literal: true

module AuthHelper
  extend ActiveSupport::Concern

  def verify_feature_flag!(flag, user = @current_user, error_message: nil)
    return if Flipper.enabled?(flag, user)

    message = error_message || "#{flag} is disabled for user"
    Rails.logger.error(message:)
    raise Common::Exceptions::ServiceUnavailable, message:
  end

  def validate_claim_id_exists!(claim_id)
    # NOTE: In request specs, you can’t make params[:claim_id] truly missing because
    # it’s part of the URL path and Rails routing prevents that.
    raise Common::Exceptions::BadRequest.new(detail: 'Claim ID is required') if claim_id.blank?

    # ensure claim ID is the right format, allowing any version
    uuid_all_version_format = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}\z/i

    unless uuid_all_version_format.match?(claim_id)
      raise Common::Exceptions::BadRequest.new(
        detail: 'Claim ID is invalid'
      )
    end
  end
end
