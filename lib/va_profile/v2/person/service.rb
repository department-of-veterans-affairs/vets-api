# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'va_profile/v2/contact_information/configuration'
require 'va_profile/v2/contact_information/transaction_response'
require 'va_profile/service'
require 'va_profile/stats'
require 'identity/parsers/gc_ids_constants'

module VAProfile
  module V2
    module Person
      class Service < VAProfile::Service
        include Common::Client::Concerns::Monitoring
        include ERB::Util

        STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.person".freeze
        configuration VAProfile::V2::ContactInformation::Configuration

        # Initializes a vet360_id for a user that does not have one. Can be used when a current user
        # is present, or through a rake task when no user is present (through passing in their ICN).
        # This is an asynchronous process for VAProfile, so it returns VAProfile transaction information.
        #
        # @return [VAProfile::V2::ContactInformation::PersonTransactionResponse]
        # response wrapper around a transaction object
        #
        def init_vet360_id
          with_monitoring do
            raw_response = perform(:post, "#{MPI::Constants::VA_ROOT_OID}/#{ERB::Util.url_encode(uuid_with_aaid)}",
                                   empty_body)
            VAProfile::V2::ContactInformation::PersonTransactionResponse.from(raw_response, @user)
          end
        rescue => e
          handle_error(e)
        end

        private

        # @see https://ruby-doc.org/stdlib-2.3.0/libdoc/erb/rdoc/ERB/Util.html
        #
        def uuid_with_aaid
          return "#{@user.idme_uuid}^PN^200VIDM^USDVA" if @user.idme_uuid
          return "#{@user.logingov_uuid}^PN^200VLGN^USDVA" if @user.logingov_uuid
          return "#{@user.vet360_id}^PI^200VETS^USDVA" if @user.idme_uuid.blank? && @user.logingov_uuid.blank?

          nil
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
end
