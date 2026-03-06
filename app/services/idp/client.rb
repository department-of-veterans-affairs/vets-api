# frozen_string_literal: true

require 'cgi'
require 'digest'
require 'openssl'

module Idp
  class Client
    DEFAULT_TIMEOUT = 15
    HMAC_HEADER_USER_ID = 'X-IDP-User-Id'
    HMAC_HEADER_TIMESTAMP = 'X-IDP-Timestamp'
    HMAC_HEADER_KEY_ID = 'X-IDP-Key-Id'
    HMAC_HEADER_SIGNATURE = 'X-IDP-Signature'

    def initialize(base_url: nil, timeout: nil, hmac_key_id: nil, hmac_secret: nil)
      @base_url = base_url.presence ||
                  Settings.dig(:cave, :idp, :base_url)

      @timeout = timeout ||
                 Settings.dig(:cave, :idp, :timeout) ||
                 DEFAULT_TIMEOUT
      @hmac_key_id = hmac_key_id.presence ||
                     Settings.dig(:cave, :idp, :hmac, :key_id) ||
                     ENV.fetch('bio__IDP_HMAC_KEY_ID', nil)
      @hmac_secret = hmac_secret.presence ||
                     Settings.dig(:cave, :idp, :hmac, :secret) ||
                     ENV.fetch('bio__IDP_HMAC_SECRET', nil)
      raise Idp::Error, 'IDP base URL is not configured' if @base_url.blank?
    end

    def intake(file_name:, pdf_base64:, user_id:)
      post(
        'intake',
        { pdf_b64: pdf_base64 },
        request_context: { operation: 'intake', user_id: },
        headers: { 'X-Filename' => file_name }
      )
    end

    def status(id, user_id:)
      get('status', { id: }, operation: 'status', user_id:)
    end

    def output(id, type:, user_id:)
      get('output', { id:, type: }, operation: 'output', user_id:)
    end

    def download(id, kvpid:, user_id:)
      get('download', { id:, kvpid: }, operation: 'download', user_id:)
    end

    def update(id, kvpid:, payload:, user_id:)
      post(
        'update',
        payload,
        request_context: { operation: 'update', user_id: },
        params: { id:, kvpid: }
      )
    end

    private

    attr_reader :base_url, :timeout, :hmac_key_id, :hmac_secret

    def connection
      @connection ||= Faraday.new(url: normalized_base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :raise_error
        conn.options.timeout = timeout
        conn.options.open_timeout = timeout
        conn.adapter Faraday.default_adapter
      end
    end

    def normalized_base_url
      base_url.end_with?('/') ? base_url : "#{base_url}/"
    end

    def get(path, params = {}, operation:, user_id:)
      request_context = {
        method: 'GET',
        operation:,
        params:,
        body: nil,
        user_id:
      }

      perform_request(operation:) do
        connection.get(path, params) do |req|
          add_identity_headers(req:, request_context:)
        end
      end
    end

    def post(path, body, request_context:, headers: {}, params: {})
      canonical_body = canonical_json(body)
      canonical_params = params.to_h
      signed_request_context = request_context.merge(
        method: 'POST',
        params: canonical_params,
        body: canonical_body
      )

      perform_request(operation: request_context[:operation]) do
        connection.post(path) do |req|
          req.params.update(canonical_params) if canonical_params.present?
          req.headers['Content-Type'] = 'application/json'
          headers.each do |key, value|
            req.headers[key] = value if value.present?
          end
          req.body = canonical_body
          add_identity_headers(req:, request_context: signed_request_context)
        end
      end
    end

    def add_identity_headers(req:, request_context:)
      resolved_user_id = request_context[:user_id].to_s
      raise Idp::Error, 'IDP user identity is required' if resolved_user_id.blank?

      req.headers[HMAC_HEADER_USER_ID] = resolved_user_id
      return unless signing_configured?

      timestamp = Time.now.to_i.to_s
      req.headers[HMAC_HEADER_TIMESTAMP] = timestamp
      req.headers[HMAC_HEADER_KEY_ID] = hmac_key_id if hmac_key_id.present?
      req.headers[HMAC_HEADER_SIGNATURE] = hmac_signature(
        request_context: request_context.merge(user_id: resolved_user_id),
        timestamp:
      )
    end

    def signing_configured?
      hmac_secret.present?
    end

    def hmac_signature(request_context:, timestamp:)
      payload = [
        timestamp,
        request_context[:method].to_s.upcase,
        request_context[:operation].to_s,
        canonical_query(request_context[:params]),
        Digest::SHA256.hexdigest(request_context[:body].to_s),
        request_context[:user_id].to_s
      ].join("\n")

      OpenSSL::HMAC.hexdigest('SHA256', hmac_secret, payload)
    end

    def canonical_query(params)
      return '' if params.blank?

      pairs = params.to_h.flat_map do |key, value|
        values = value.is_a?(Array) ? value : [value]
        values.compact.map { |entry| [key.to_s, entry.to_s] }
      end

      pairs.sort_by! { |key, value| [key, value] }
      pairs.map { |key, value| "#{CGI.escape(key)}=#{CGI.escape(value)}" }.join('&')
    end

    def canonical_json(value)
      JSON.generate(sort_json(value))
    end

    def sort_json(value)
      case value
      when Hash
        value.keys.sort_by(&:to_s).each_with_object({}) do |key, sorted|
          sorted[key.to_s] = sort_json(value[key])
        end
      when Array
        value.map { |entry| sort_json(entry) }
      else
        value
      end
    end

    def perform_request(operation:)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = yield
      Rails.logger.info('[Idp::Client] request success', {
                          operation:,
                          duration: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(4),
                          status: response.status
                        })
      response.body
    rescue Faraday::Error => e
      error_type = extract_error_type(e.response)
      Rails.logger.error('[Idp::Client] request error', {
                           operation:,
                           duration: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(4),
                           error_class: e.class.name,
                           error_type:
                         })
      raise Idp::Error.new(e.message, error_type:, operation:)
    end

    def extract_error_type(response)
      body = response&.[](:body)

      case body
      when Hash
        body['error_type']
      when String
        JSON.parse(body)['error_type']
      end
    rescue JSON::ParserError, TypeError
      nil
    end
  end
end
