# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'erb'

module V0
  class VirtualAgentSpeechTokenController < ApplicationController
    skip_before_action :authenticate, only: [:create]

    rescue_from 'V0::VirtualAgentSpeechTokenController::ServiceException', with: :service_exception_handler
    rescue_from Net::HTTPError, with: :service_exception_handler

    def create
      speech_token = request_connector_values
      render json: { token: speech_token }
    end

    private

    def request_connector_values
      speech_token_request_uri = Settings.virtual_agent.speech_token_request_uri
      speech_token_subscription_key = Settings.virtual_agent.speech_token_subscription_key
      token_endpoint_uri = URI(speech_token_request_uri)
      req = Net::HTTP::Post.new(token_endpoint_uri)
      req['Ocp-Apim-Subscription-Key'] = speech_token_subscription_key
      res = Net::HTTP.start(token_endpoint_uri.hostname, token_endpoint_uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      raise ServiceException.new(res.body), res.body unless res.code == '200'

      res.body
    end

    def service_exception_handler(exception)
      context = 'An error occurred with the Microsoft service that issues chatbot tokens'
      log_exception_to_sentry(exception, 'context' => context)
      render nothing: true, status: :service_unavailable
    end

    class ServiceException < RuntimeError; end
  end
end
