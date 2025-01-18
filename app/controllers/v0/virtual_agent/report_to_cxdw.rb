# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'openssl'
require 'json'

module V0
  module VirtualAgent
    class ReportToCxdw
      def report_to_cxdw(icn, conversation_id)
        dataverse_uri = Settings.virtual_agent.cxdw_dataverse_uri
        token = get_new_token dataverse_uri
        send_to_cxdw dataverse_uri, icn, conversation_id, token
      end

      private

      def get_new_token(dataverse_uri)
        app_uri = Settings.virtual_agent.cxdw_app_uri
        client_id = Settings.virtual_agent.cxdw_client_id
        client_secret = Settings.virtual_agent.cxdw_client_secret

        url = URI("#{app_uri}/oauth2/v2.0/token")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT

        body_grant_type = 'grant_type=client_credentials'
        body_client_id = "client_id=#{client_id}"
        body_client_secret = "client_secret=#{client_secret}"
        body_scope = "scope=#{dataverse_uri}"

        request = Net::HTTP::Post.new(url)
        request['content-type'] = 'application/x-www-form-urlencoded'
        request.body = "#{body_grant_type}&#{body_client_id}&#{body_client_secret}&#{body_scope}/.default"

        response = http.request(request)
        JSON.parse(response.read_body)['access_token']
      rescue => e
        raise StandardError, "Errored retreiving dataverse token with error: #{e}"
      end

      def send_to_cxdw(dataverse_uri, icn, conversation_id, token)
        cxdw_table_prefix = Settings.virtual_agent.cxdw_table_prefix
        response = Net::HTTP.post URI("#{dataverse_uri}/api/data/v9.2//#{cxdw_table_prefix}claimsqueries"),
                                  {
                                    "#{cxdw_table_prefix}id" => "#{conversation_id} - #{Time.current}",
                                    "#{cxdw_table_prefix}icn" => icn,
                                    "#{cxdw_table_prefix}conversationid" => conversation_id,
                                    "#{cxdw_table_prefix}requestedtimestamp" => Time.current.to_s
                                  }.to_json,
                                  {
                                    'Content-Type' => 'application/json; charset=utf-8',
                                    'OData-MaxVersion' => '4.0',
                                    'OData-Version' => '4.0',
                                    'If-None-Match' => 'null',
                                    'Authorization' => "Bearer #{token}"
                                  }
        if response.code == '204'
          response
        else
          raise StandardError, "Errored posting to dataverse with response code #{response.code}"
        end
      end
    end
  end
end
