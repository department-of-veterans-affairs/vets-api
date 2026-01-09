# frozen_string_literal: true

module NotificationsClientPatch
  UUID_LENGTH = 36
  MINIMUM_TOKEN_LENGTH = 75
  URLSAFE_TOKEN_LENGTH = 86

  def initialize(secret_token = nil, base_url = nil)
    return super unless Flipper.enabled?(:va_notify_enhanced_uuid_validation)

    token_length = detect_token_length(secret_token)
    @secret_token = secret_token[-token_length..]
    @service_id = secret_token[-(token_length + 1 + UUID_LENGTH)..-(token_length + 2)]
    @base_url = base_url || PRODUCTION_BASE_URL

    validate_uuids!
  end

  def validate_uuids!
    return super unless Flipper.enabled?(:va_notify_enhanced_uuid_validation)

    raise ArgumentError, "Invalid service_id format: #{@service_id}" unless valid_uuid?(@service_id)

    raise ArgumentError, "Invalid secret_token format: #{@secret_token}" unless valid_token?(@secret_token)

    Rails.logger.info('NotificationsClientPatch: validation successful')
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

  def detect_token_length(secret_token)
    # minimum length includes 2 uuids, dashes, and a character for name
    unless secret_token.is_a?(String) && secret_token.length >= MINIMUM_TOKEN_LENGTH
      raise ArgumentError, "Invalid secret_token format: #{secret_token}"
    end

    potential_uuid = secret_token[-UUID_LENGTH..]
    if valid_uuid?(potential_uuid)
      Rails.logger.info('NotificationsClientPatch: Detected uuid format for api_key')
      UUID_LENGTH
    else
      Rails.logger.info('NotificationsClientPatch: Detected urlsafe format for api_key')
      URLSAFE_TOKEN_LENGTH
    end
  end
end

# prevents a race condition when booting up Rails
# Speaker.prepend inserts a method signature for validate_uuids! which patches the original version
Rails.configuration.to_prepare do
  require "notifications/client"
  Notifications::Client::Speaker.prepend(NotificationsClientPatch)
end
