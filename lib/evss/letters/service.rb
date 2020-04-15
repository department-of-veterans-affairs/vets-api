# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'
require 'common/client/concerns/monitoring'

module EVSS
  module Letters
    ##
    # Proxy Service for Letters Caseflow.
    #
    # @example Creating a service and fetching letters for a user
    #   letters_response = EVSS::Letters::Service.new.get_letters
    #
    class Service < EVSS::Service
      configuration EVSS::Letters::Configuration

      INVALID_ADDRESS_ERROR = 'letterDestination.addressLine1.invalid'

      ##
      # Returns letters for a user.
      #
      # @return [EVSS::Letters::LettersResponse] Contains the user's name and an
      # array of letter objects
      #
      def get_letters
        with_monitoring do
          raw_response = perform(:get, '')
          EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
        end
      rescue => e
        handle_error(e)
      end

      ##
      # Returns benefit and service information for a user.
      #
      # @return [EVSS::Letters::BeneficiaryResponse] Contains benefit information and
      # an array of military service objects
      #
      def get_letter_beneficiary
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'letterBeneficiary')
          EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def handle_error(error)
        Raven.tags_context(team: 'benefits-memorial-1') # tag sentry logs with team name
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          begin
            log_edipi if invalid_address_error?(error)
          ensure
            save_error_details(error)
            raise EVSS::Letters::ServiceException, error.body
          end
        else
          super(error)
        end
      end

      def log_edipi
        InvalidLetterAddressEdipi.find_or_create_by(edipi: @user.edipi)
      end

      def invalid_address_error?(error)
        error.body.dig('messages')&.any? { |m| m['key'].include? INVALID_ADDRESS_ERROR }
      end
    end
  end
end
