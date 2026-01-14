# frozen_string_literal: true

module ClaimsApi
  class UpstreamFaradayHealthcheckController < ApplicationController
    service_tag 'lighthouse-claims'
    skip_before_action :authenticate
    def corporate
      st = DateTime.now
      ssl_type = Settings.bep.ssl_verify_mode == 'none' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      connection = Faraday::Connection.new(ssl: { verify_mode: ssl_type })
      connection.options.timeout = 5

      begin
        response = connection.get("#{Settings.bep.url}/CorporateUpdateServiceBean/CorporateUpdateWebService?WSDL")
      rescue
        et = DateTime.now
        render json: { st:, et:, dur: (et.to_f - st.to_f),
                       error: "Timeout - Exceeded #{connection.options.timeout}s" } and return
      end

      et = DateTime.now
      render json: { st:, et:, dur: (et.to_f - st.to_f), status: response.status }
    end

    def claimant
      st = DateTime.now
      ssl_type = Settings.bep.ssl_verify_mode == 'none' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      connection = Faraday::Connection.new(ssl: { verify_mode: ssl_type })
      connection.options.timeout = 5

      begin
        response = connection.get("#{Settings.bep.url}/ClaimantServiceBean/ClaimantWebService?WSDL")
      rescue
        et = DateTime.now
        render json: { st:, et:, dur: (et.to_f - st.to_f),
                       error: "Timeout - Exceeded #{connection.options.timeout}s" } and return
      end

      et = DateTime.now
      render json: { st:, et:, dur: (et.to_f - st.to_f), status: response.status }
    end

    def itf
      st = DateTime.now
      ssl_type = Settings.bep.ssl_verify_mode == 'none' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      connection = Faraday::Connection.new(ssl: { verify_mode: ssl_type })
      connection.options.timeout = 5

      begin
        response = connection.get("#{Settings.bep.url}/IntentToFileWebServiceBean/IntentToFileWebService?WSDL")
      rescue
        et = DateTime.now
        render json: { st:, et:, dur: (et.to_f - st.to_f),
                       error: "Timeout - Exceeded #{connection.options.timeout}s" } and return
      end

      et = DateTime.now
      render json: { st:, et:, dur: (et.to_f - st.to_f), status: response.status }
    end
  end
end
