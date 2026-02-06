# frozen_string_literal: true

module NotificationsClientPatch
  UUID_LENGTH = 36
  # urlsafe token length is 86
  URLSAFE_TOKEN_LENGTH = 86
  # Format: name-service_id-secret_token
  # (e.g., "myapp-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
  # Minimum: 1 char name + dash + UUID (36) + dash + UUID (36) = 75
  MINIMUM_TOKEN_LENGTH = 1 + 1 + UUID_LENGTH + 1 + UUID_LENGTH
  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  PRODUCTION_BASE_URL = 'https://api.notifications.va.gov'

  def initialize(secret_token = nil, base_url = nil)
    unless Flipper.enabled?(:va_notify_enhanced_uuid_validation)
      super
      return
    end

    token_length = detect_token_length(secret_token)
    @secret_token = extract_secret_token(secret_token, token_length)
    @service_id = extract_service_id(secret_token, token_length)
    @base_url = base_url || PRODUCTION_BASE_URL

    validate_uuids!
  end

  def extract_secret_token(secret_token, token_length)
    secret_token[-token_length..]
  end

  def extract_service_id(secret_token, token_length)
    start_index = -(token_length + 1 + UUID_LENGTH)
    end_index = -(token_length + 2)
    secret_token[start_index..end_index]
  end

  def validate_uuids!
    return super unless Flipper.enabled?(:va_notify_enhanced_uuid_validation)

    raise ArgumentError, 'Invalid service_id format' unless valid_uuid?(@service_id)

    raise ArgumentError, 'Invalid secret_token format' unless valid_token?(@secret_token)

    Rails.logger.info('NotificationsClientPatch: validation successful')
  end

  private

  def valid_uuid?(uuid)
    return false unless uuid.is_a?(String)

    uuid.match?(UUID_REGEX)
  end

  def valid_token?(token)
    return false unless token.is_a?(String)

    # Standard UUID format (36 chars)
    return true if token.match?(UUID_REGEX)

    # Python secrets.token_urlsafe(64) format (86 chars, URL-safe base64)
    return true if token.length >= URLSAFE_TOKEN_LENGTH && token.match?(/\A[A-Za-z0-9_-]+\z/)

    false
  end

  def detect_token_length(secret_token)
    validate_secret_token_format!(secret_token)

    uuid_format = uuid_format_token?(secret_token)
    log_detected_format(uuid_format)
    uuid_format ? UUID_LENGTH : URLSAFE_TOKEN_LENGTH
  end

  def uuid_format_token?(secret_token)
    potential_uuid = secret_token[-UUID_LENGTH..]
    valid_uuid?(potential_uuid)
  end

  def log_detected_format(uuid_format)
    format_type = uuid_format ? 'uuid' : 'urlsafe'
    Rails.logger.info("NotificationsClientPatch: Detected #{format_type} format for api_key")
  end

  def validate_secret_token_format!(secret_token)
    return if secret_token.is_a?(String) && secret_token.length >= MINIMUM_TOKEN_LENGTH

    raise ArgumentError, 'Invalid secret_token format'
  end
end

# Use `to_prepare` so the patch is applied after Rails has loaded the target class and on every reload.
# Without this, if we called `prepend` at file load time, Rails might:
#   * Load this initializer before `Notifications::Client::Speaker` is autoloaded, so the prepend would
#     either fail or run against a different constant, and
#   * In development/test, reload `Notifications::Client::Speaker` later without re-applying the patch,
#     causing some requests/jobs to see the patched `validate_uuids!` and others to see the original.
# `Rails.configuration.to_prepare` runs:
#   * Once at boot in production (after application classes are loaded), and
#   * Before each request and code reload cycle in development/test.
# This guarantees that `Notifications::Client::Speaker` is loaded before we call `prepend`, and that the
# patch is consistently re-applied whenever Rails reloads the class, avoiding the race described above.
Rails.configuration.to_prepare do
  require 'notifications/client'
  Notifications::Client::Speaker.prepend(NotificationsClientPatch)
end
