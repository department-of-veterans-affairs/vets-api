# frozen_string_literal: true

require 'mhv/account_creation/configuration'

module MHV
  module AccountCreation
    class Service < Common::Client::Base
      configuration Configuration

      def create_account(icn:, email:, tou_occurred_at:)
        params = build_create_account_params(icn:, email:, tou_occurred_at:)

        response = perform(:post, config.account_creation_path, params, authenticated_header(icn:))
        Rails.logger.info("#{config.logging_prefix} create_account success", icn:)

        normalize_response_body(response.body)
      rescue Common::Client::Errors::ParsingError, Common::Client::Errors::ClientError => e
        Rails.logger.error("#{config.logging_prefix} create_account #{e.class.name.demodulize.underscore}",
                           { error_message: e.message, body: e.body, icn: })
        raise
      end

      private

      def build_create_account_params(icn:, email:, tou_occurred_at:)
        {
          icn:,
          email:,
          vaTermsOfUseDateTime: tou_occurred_at.iso8601,
          vaTermsOfUseStatus: config.tou_status,
          vaTermsOfUseRevision: config.tou_revision,
          vaTermsOfUseLegalVersion: config.tou_legal_version,
          vaTermsOfUseDocTitle: config.tou_doc_title
        }.to_json
      end

      def authenticated_header(icn:)
        {
          'Authorization' => "Bearer #{config.sts_token(user_identifier: icn)}",
          'x-api-key' => config.access_key
        }
      end

      def normalize_response_body(response_body)
        {
          user_profile_id: response_body['mhv_userprofileid'],
          premium: response_body['isPremium'],
          champ_va: response_body['isChampVA'],
          patient: response_body['isPatient'],
          sm_account_created: response_body['isSMAccountCreated'],
          message: response_body['message']
        }
      end
    end
  end
end
