# frozen_string_literal: true

require 'common/client/base'
require 'vet360/contact_information/transaction_response'

module Vet360
  module Person
    class Service < Vet360::Service
      include Common::Client::Monitoring

      AAID = MVI::Responses::IdParser::VET360_ASSIGNING_AUTHORITY_ID
      OID  = MVI::Responses::IdParser::CORRELATION_ROOT_ID

      configuration Vet360::ContactInformation::Configuration

      def init_vet360_id(icn = nil)
        with_monitoring do
          raw_response = perform(:post, encode_uri!(icn), empty_body)

          Vet360::ContactInformation::PersonTransactionResponse.from(raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      # rubocop:disable Lint/UriEscapeUnescape
      def encode_uri!(icn)
        URI.encode("#{OID}/#{build_icn_with_aaid!(icn)}")
      end
      # rubocop:enable Lint/UriEscapeUnescape

      def build_icn_with_aaid!(icn)
        if icn.present?
          "#{icn}#{AAID}"
        elsif @user&.icn_with_aaid.present?
          @user.icn_with_aaid
        else
          raise 'User does not have an ICN with an Assigning Authority ID'
        end
      end

      def empty_body
        {
          bio: {
            sourceDate: Time.zone.now.iso8601
          }
        }.to_json
      end
    end
  end
end
