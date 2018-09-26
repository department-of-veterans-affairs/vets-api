# frozen_string_literal: true

class RelayState
  extend ActiveModel::Naming
  include ActiveModel::Validations
  include SentryLogging

  attr_accessor :relay_enum, :url

  RELAY_KEYS = Settings.saml.relays.keys.map(&:to_s).freeze
  LOGIN_URLS = (Settings.saml.relays.to_h.values + [Settings.review_instance_slug]).compact.freeze
  LOGOUT_URLS = (Settings.saml.logout_relays.to_h.values + [Settings.saml.logout_relay]).compact.freeze
  ALL_RELAY_URLS = (LOGIN_URLS + LOGOUT_URLS).freeze

  validates :relay_enum, allow_blank: true, inclusion: { in: RELAY_KEYS, message: '[%<value>s] not a valid relay enum' }
  validates :url, allow_blank: true, inclusion: { in: ALL_RELAY_URLS, message: '[%<value>s] not a valid relay url' }
  # TODO: Custom validator that BOTH are not blank

  def initialize(relay_enum: nil, url: nil)
    @relay_enum = relay_enum
    @url = url

    unless valid?
      log_message_to_sentry(
        'Invalid SAML RelayState!', :error,
        error_messages: errors.messages, url_whitelist: ALL_RELAY_URLS, enum_whitelist: RELAY_KEYS
      )
    end
  end

  def login_url
    return default_login_url if @relay_enum.blank? && @url.blank?
    return Settings.saml.relays.vetsgov if @url.present? && @url == Settings.review_instance_slug
    get_url(LOGIN_URLS + [], :relays)
  end

  def logout_url
    return default_logout_url if @relay_enum.blank? && @url.blank?
    return Settings.saml.logout_relay if @url.present? && @url == Settings.review_instance_slug
    get_url(LOGOUT_URLS, :logout_relays)
  end

  def default_login_url
    Settings.saml.relays&.vetsgov || Settings.saml.relay
  end

  def default_logout_url
    Settings.saml.logout_relays&.vetsgov || Settings.saml.logout_relay
  end

  private

  def get_url(valid_urls, type)
    return get_default(type) unless valid?
    return get_default(type) if @url.present? && valid_urls.include?(@url) == false

    if @url.present?
      return @url
    elsif Settings.saml[type][@relay_enum].present?
      return Settings.saml[type][@relay_enum]
    else
      return get_default(type)
    end
  end

  def get_default(type = :relays)
    type == :logout_relays ? default_logout_url : default_login_url
  end
end
