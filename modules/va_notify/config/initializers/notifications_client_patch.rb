# frozen_string_literal: true

module NotificationsClientPatch
  def validate_uuids!
    raise ArgumentError, "Invalid service_id format: #{@service_id}" unless valid_uuid?(@service_id)

    raise ArgumentError, "Invalid secret_token format: #{@secret_token}" unless valid_token?(@secret_token)
  end

  private

  def valid_uuid?(uuid)
    return false unless uuid.is_a?(String)

    # Standard UUID format (36 chars, case-insensitive)
    uuid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end

  def valid_token?(token)
    return false unless token.is_a?(String)

    # Standard UUID format (36 chars)
    return true if token.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

    # Python secrets.token_urlsafe(64) format (86+ chars, URL-safe base64)
    return true if token.length >= 86 && token.match?(/\A[A-Za-z0-9_-]+\z/)

    false
  end
end

# prevents a race condition when booting up Rails
# Speaker.prepend inserts a method signature for validate_uuids! which patches the original version
Rails.configuration.to_prepare do
  require 'notifications/client'
  Notifications::Client::Speaker.prepend(NotificationsClientPatch)
end
