# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module MHV
  module AccountCreation
    class Configuration < Common::Client::Configuration::REST
      def base_path
        IdentitySettings.mhv.account_creation.host
      end

      def service_name
        'mhv_account_creation'
      end

      def account_creation_path
        'v1/usermgmt/account-service/account'
      end

      def logging_prefix
        '[MHV][AccountCreation][Service]'
      end

      def tou_status
        'accepted'
      end

      def tou_revision
        '3'
      end

      def tou_legal_version
        '1.0'
      end

      def tou_doc_title
        'VA Enterprise Terms of Use'
      end

      def access_key
        IdentitySettings.mhv.account_creation.access_key
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          conn.adapter Faraday.default_adapter
          conn.response :json
          conn.response :betamocks if IdentitySettings.mhv.account_creation.mock
        end
      end

      def sts_token(user_identifier:)
        token = sts_client(user_identifier).token
        Rails.logger.info("#{logging_prefix} sts token request success", user_identifier:)
        token
      rescue SignInService::Error => e
        error_message = e.message
        Rails.logger.error("#{logging_prefix} sts token request failed", user_identifier:, error_message:)
        raise Common::Client::Errors::ClientError, error_message
      end

      private

      def sts_client(user_identifier)
        SignInService::Sts.new(
          service_account_id: mhv_sts_settings.service_account_id,
          issuer: mhv_sts_settings.issuer,
          private_key_path: IdentitySettings.sign_in.sts_client.key_path,
          scopes: sts_scopes,
          user_identifier:,
          user_attributes: { icn: user_identifier }
        )
      end

      def sts_scopes
        ["#{base_path}/#{account_creation_path}"]
      end

      def mhv_sts_settings
        IdentitySettings.mhv.account_creation.sts
      end
    end
  end
end
