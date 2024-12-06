# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'va_profile/contact_information/configuration'
require 'va_profile/contact_information/transaction_response'
require 'va_profile/service'
require 'va_profile/stats'
require 'identity/parsers/gc_ids_constants'

module VAProfile
  module Person
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring
      include ERB::Util

      STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.person".freeze
      configuration VAProfile::ContactInformation::Configuration

      # Initializes a vet360_id for a user that does not have one. Can be used when a current user
      # is present, or through a rake task when no user is present (through passing in their ICN).
      # This is an asynchronous process for VAProfile, so it returns VAProfile transaction information.
      #
      # @param icn [String] A users ICN. Only required when current user is absent.  Intended to be used in a rake task.
      # @return [VAProfile::ContactInformation::PersonTransactionResponse] response wrapper around a transaction object
      #
      def init_vet360_id(icn = nil)
        with_monitoring do
          raw_response = perform(:post, encode_url!(icn), empty_body)
          VAProfile::ContactInformation::PersonTransactionResponse.from(raw_response, @user)
        end
      rescue => e
        handle_error(e)
      end

      private

      # @see https://ruby-doc.org/stdlib-2.3.0/libdoc/erb/rdoc/ERB/Util.html
      #
      def encode_url!(icn)
        encoded_icn_with_aaid = url_encode(build_icn_with_aaid!(icn))

        "#{Identity::Parsers::GCIdsConstants::VA_ROOT_OID}/#{encoded_icn_with_aaid}"
      end

      def build_icn_with_aaid!(icn)
        if icn.present?
          "#{icn}#{Identity::Parsers::GCIdsConstants::ICN_ASSIGNING_AUTHORITY_ID}"
        elsif @user&.icn_with_aaid.present?
          @user.icn_with_aaid
        else
          raise 'User does not have a valid ICN with an Assigning Authority ID'
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
