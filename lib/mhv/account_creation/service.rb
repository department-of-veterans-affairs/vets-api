# frozen_string_literal: true

require 'mhv/account_creation/configuration'

module MHV
  module AccountCreation
    class Service < Common::Client::Base
      configuration Configuration

      def create_account(icn:, email:, tou_occurred_at:, break_cache: false)
        params = build_create_account_params(icn:, email:, tou_occurred_at:)

        create_account_with_cache(icn:, force: break_cache, expires_in: 1.day) do
          Rails.logger.info("#{config.logging_prefix} create_account request", { icn: })
          response = perform(:post, config.account_creation_path, params, authenticated_header(icn:))
          normalize_response_body(response.body)
        end
      rescue Common::Client::Errors::ParsingError, Common::Client::Errors::ClientError => e
        Rails.logger.error("#{config.logging_prefix} create_account #{e.class.name.demodulize.underscore}",
                           { error_message: e.message, body: e.body, status: e.status, icn: })
        raise
      end

      private

      def create_account_with_cache(icn:, force:, expires_in:, &request)
        cache_hit = true
        account = Rails.cache.fetch("#{config.service_name}_#{icn}", force:, expires_in:) do
          cache_hit = false
          request.call
        end
        Rails.logger.info("#{config.logging_prefix} create_account success", { icn:, account:, from_cache: cache_hit })

        account
      end

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
          user_profile_id: response_body['mhv_userProfileId'],
          premium: response_body['isPremium'],
          champ_va: response_body['isChampVABeneficiary'],
          patient: response_body['isPatient'],
          sm_account_created: response_body['isSMAccountCreated'],
          message: response_body['message']
        }
      end
    end
  end
end
