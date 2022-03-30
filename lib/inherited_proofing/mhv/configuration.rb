# frozen_string_literal: true

require 'common/client/configuration/rest'

module InheritedProofing
  module MHV
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.mhv.inherited_proofing.base_path
      end

      def valid_id_url
        "#{Settings.mhv.inherited_proofing.base_path}/validmhvid"
      end

      def vacct_info_url
        "#{Settings.mhv.inherited_proofing.base_path}/mhvacctinfo"
      end

      def app_token
        Settings.mhv.inherited_proofing.app_token
      end

      def service_name
        'mhv_inherited_proofing'
      end

      def connection
        @connection ||= Faraday.new(
          base_path,
          headers: base_request_headers,
          request: request_options
        ) do |conn|
          conn.use :breakers
          conn.response :betamocks if Settings.mhv.inherited_proofing.mock
          conn.use Faraday::Response::RaiseError
          conn.response :snakecase
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
