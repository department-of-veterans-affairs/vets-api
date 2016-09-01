# frozen_string_literal: true
class HealthcareMessagingController < ApplicationController
  # FIXME: when ID.me is working we need to use it here, but for now skip
  #   and just rely on the http basic authentication.
  skip_before_action :authenticate
  before_action :authenticate_client
  include ActionController::Serialization

  ######################################################################################################################
  ## MHV_CONFIG
  ## Instantiates a new configuration used in establishing a session.
  ######################################################################################################################
  MHV_CONFIG = VAHealthcareMessaging::Configuration.new(
    host: ENV['MHV_SM_HOST'],
    app_token: ENV['MHV_SM_APP_TOKEN'],
    enforce_ssl: Rails.env.production?
  ).freeze

  ######################################################################################################################
  ## Pagingation constants
  ######################################################################################################################
  DEFAULT_PER_PAGE = 10
  MAXIMUM_PER_PAGE = 100

  protected

  ######################################################################################################################
  ## client
  ## Establishes a session using the MHV correlation id for authentication.
  ######################################################################################################################
  def client
    @client ||= VAHealthcareMessaging::Client.new(config: MHV_CONFIG, session: { user_id: correlation_id })
  end

  ######################################################################################################################
  ## correlation_id
  ## Abstracting out how correlation id is obtained in the id.me world.
  ## TODO: recode once id.me is established.
  ######################################################################################################################
  def correlation_id
    @mhv_correlation_id ||= params[:id]
  end

  ######################################################################################################################
  ## authenticate_client
  ## Establishes a session using the MHV correlation id for authentication.
  ######################################################################################################################
  def authenticate_client
    client.authenticate if client.session.expired?
  end
end
