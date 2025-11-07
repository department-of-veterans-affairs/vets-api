# frozen_string_literal: true

require 'json'
require 'common/client/base'
require 'ivc_champva/monitor'
require_relative 'configuration'

module IvcChampva
  module LlmProcessorApi
    class LlmProcessorApiError < StandardError; end

    class Client < Common::Client::Base
      configuration IvcChampva::LlmProcessorApi::Configuration

      def settings
        Settings.ivc_champva_llm_processor_api
      end

      ##
      # HTTP POST call to the LLM processor service to process a document
      #
      # @param transaction_uuid [String] the UUID for the transaction
      # @param acting_user [String, nil] the acting user for the request
      # @param request_data [Hash] the request data containing :file_path and :prompt
      def process_document(transaction_uuid, acting_user, request_data)
        resp = connection.post('/files/ProcessFiles') do |req|
          req.headers.update(headers(transaction_uuid, acting_user))
          req.body = build_multipart_body(request_data)
        end

        monitor.track_llm_processor_response(transaction_uuid, resp.status, resp.body.to_s)

        raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

        resp
      rescue => e
        raise LlmProcessorApiError, e.message.to_s
      end

      ##
      # Assembles headers for the LLM processor API request
      #
      # @param transaction_uuid [String] the transaction UUID
      # @param acting_user [String, nil] the acting user
      # @return [Hash] the headers
      def headers(transaction_uuid, acting_user)
        {
          'api-key' => config.api_key,
          'transactionUUID' => transaction_uuid.to_s,
          'acting-user' => acting_user.to_s
        }
      end

      ##
      # Builds multipart form body for the LLM processor API request
      #
      # @param request_data [Hash] the request data containing :file_path and :prompt
      # @return [Hash] the multipart form body
      def build_multipart_body(request_data)
        {
          file: Faraday::UploadIO.new(request_data[:file_path], 'application/pdf'),
          user_prompt: request_data[:prompt]
        }
      end

      ##
      # retrieve a monitor for tracking
      #
      # @return [IvcChampva::Monitor]
      #
      def monitor
        @monitor ||= IvcChampva::Monitor.new
      end
    end
  end
end
