# frozen_string_literal: true

require 'common/client/base'
require 'vet360/contact_information/transaction_response'

module Vet360
  module Person
    class Service < Vet360::Service
      include Common::Client::Monitoring
      include ERB::Util

      AAID = MVI::Responses::IdParser::VET360_ASSIGNING_AUTHORITY_ID
      OID  = MVI::Responses::IdParser::CORRELATION_ROOT_ID

      configuration Vet360::ContactInformation::Configuration

      # Initializes a vet360_id for a user that does not have one. Can be used when a current user
      # is present, or through a rake task when no user is present (through passing in their ICN).
      # This is an asynchronous process for Vet360, so it returns Vet360 transaction information.
      #
      # @param icn [String] A users ICN. Only required when current user is absent.  Intended to be used in a rake task.
      # @return [Vet360::ContactInformation::PersonTransactionResponse] response wrapper around a transaction object
      #
      def init_vet360_id(icn = nil)
        with_monitoring do
          raw_response = perform(:post, encode_url!(icn), empty_body)

          Vet360::ContactInformation::PersonTransactionResponse.from(raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      # @see https://ruby-doc.org/stdlib-2.3.0/libdoc/erb/rdoc/ERB/Util.html
      #
      def encode_url!(icn)
        encoded_icn_with_aaid = url_encode(build_icn_with_aaid!(icn))

        "#{OID}/#{encoded_icn_with_aaid}"
      end

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
