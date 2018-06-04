# frozen_string_literal: true

require 'common/client/base'
require 'vet360/contact_information/transaction_response'

module Vet360
  module Person
    class Service < Vet360::Service
      include Common::Client::Monitoring

      OID = MVI::Responses::IdParser::CORRELATION_ROOT_ID
      AAID = MVI::Responses::IdParser::VET360_ASSIGNING_AUTHORITY_ID

      configuration Vet360::ContactInformation::Configuration

      def init_vet360_id(icn)
        with_monitoring do
          raw_response = perform(:post, encoded_uri_for(icn), empty_body)

          Vet360::ContactInformation::PersonResponse.from(raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      # rubocop:disable Lint/UriEscapeUnescape
      def encoded_uri_for(icn, oid: OID, aaid: AAID)
        URI.encode("#{oid}/#{icn}#{aaid}")
      end
      # rubocop:enable Lint/UriEscapeUnescape

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
