# frozen_string_literal: true

module IdValidation
  extend ActiveSupport::Concern

  def validate_uuid_exists!(id, id_type = 'An')
    # NOTE: In request specs, you can’t make params[:claim_id] or params[:id] truly missing because
    # it’s part of the URL path and Rails routing prevents that.
    raise Common::Exceptions::BadRequest.new(detail: "#{id_type} ID is required") if id.blank?

    # Ensure the UUID is the right format, allowing any version
    uuid_all_version_format = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}\z/i

    unless uuid_all_version_format.match?(id)
      raise Common::Exceptions::BadRequest.new(
        detail: "#{id_type} ID is invalid"
      )
    end
  end
end
