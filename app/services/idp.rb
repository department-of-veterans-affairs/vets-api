# frozen_string_literal: true

module Idp
  class Error < StandardError; end

  # Returns the appropriate IDP client for the current environment.
  #
  # - Production/staging: Idp::Client (real HTTP calls)
  # - Development/test:   Idp::MockClient by default
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
    return true if ENV['IDP_USE_LIVE'].present?

    false
  end
  private_class_method :use_live_client?
end
