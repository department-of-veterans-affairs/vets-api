# frozen_string_literal: true

module ControllerLoggingContext
  extend ActiveSupport::Concern
  included { before_action :set_context }

  private

  def set_context
    RequestStore.store['request_id'] = request.uuid
    RequestStore.store['additional_request_attributes'] = {
      'remote_ip' => request.remote_ip,
      'user_agent' => request.user_agent,
      'user_uuid' => current_user&.uuid,
      'source' => request.headers['Source-App-Name']
    }
  end
end
