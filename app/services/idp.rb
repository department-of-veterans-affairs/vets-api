# frozen_string_literal: true

module Idp
  class Error < StandardError; end

  # Returns the appropriate IDP client for the current environment.
  #
  # - Production/staging: Idp::Client (real HTTP calls)
  # - Non-production: controlled by cave.idp.mock (defaults to true in dev/test)
  #
  # Developers who need the real service locally can set IDP_USE_LIVE=true.
  def self.client
    if use_live_client?
      Client.new
    else
      require_relative 'idp/mock_client' unless defined?(MockClient)
      MockClient.new
    end
  end

  def self.use_live_client?
    return true if Rails.env.production?

    # use ENV['IDP_USE_LIVE'] if you need to develop against the live client on localhost
    return true if ENV['IDP_USE_LIVE'].present?

    mock_setting = Settings.dig(:cave, :idp, :mock)
    return !mock_setting unless mock_setting.nil?

    false
  end
  private_class_method :use_live_client?
end
