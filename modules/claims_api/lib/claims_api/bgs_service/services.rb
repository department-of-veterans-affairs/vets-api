# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

# This file will go ahead and require all the web services that have been
# included to date, so that when a user requests `bgs`, they have all the
# required classes.
#
# All Services should be in the BGS module, not ClaimsApi::LocalBGS::Services::*, since
# the entire point of this gem is to talk with BGS Web Services. It's
# organized like this to keep conceptual things at a glance, and then dig
# in to the implementation(s) (really: declarations)

require_relative 'services/benefit_claims'
require_relative 'services/intent_to_file'
require_relative 'services/person'

# I'd like to use this instead of the sea of `require_relative` above
# however, then ObjectSpace doesn't have what it should
# Dir["services/*.rb"].each {|file| require file }

# Now, we're going to declare a class to hide the actual creation of service
# objects, since having to construct them all really sucks.

module ClaimsApi
  module LocalBGS
    class Services
      def initialize(external_uid:, external_key:)
        configuration = BGS.configuration
        @config = { env: configuration.env,
                    application: configuration.application,
                    client_ip: configuration.client_ip,
                    client_station_id: configuration.client_station_id,
                    client_username: configuration.client_username,
                    ssl_cert_file: configuration.ssl_cert_file,
                    ssl_cert_key_file: configuration.ssl_cert_key_file,
                    ssl_ca_cert: configuration.ssl_ca_cert,
                    forward_proxy_url: configuration.forward_proxy_url,
                    jumpbox_url: configuration.jumpbox_url,
                    log: configuration.log,
                    logger: configuration.logger,
                    external_uid: external_uid,
                    external_key: external_key,
                    mock_responses: configuration.mock_responses,
                    ssl_verify_mode: configuration.ssl_verify_mode }
      end

      def self.all
        ObjectSpace.each_object(Class).select { |klass| klass < ClaimsApi::LocalBGS::Base }
      end

      ClaimsApi::LocalBGS::Services.all.each do |service|
        define_method(service.service_name) do
          service.new @config
        end
      end

      # High level utility function to determine if a record can be accessed
      # in the current configuration. The logic on reading flashes this way
      # was grafted from how VBMS checks to see if the sensitivity level is
      # appropriate.
      #
      # If you need flashes later, it's likely better to find_flashes directly,
      # and catch a ClaimsApi::LocalBGS::ShareError if it's not allowed.
      #
      # This also requires the claimants service to have been implicitly loaded
      # above; which can break if the require at the top is removed, or if the
      # name changes.
      def can_access?(ssn, use_find_veteran_info = false) # rubocop:disable Style/OptionalBooleanParameter
        if use_find_veteran_info
          veteran.find_by(file_number: ssn).nil?
        else
          claimants.find_flashes(ssn).nil?
        end
        true
      rescue ClaimsApi::LocalBGS::ShareError
        false
      end
    end
  end
end
