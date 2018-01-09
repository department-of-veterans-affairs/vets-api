# frozen_string_literal: true

require 'common/client/base'
require 'mvi/configuration'
require 'mvi/responses/find_profile_response'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'mvi/errors/errors'

module MVI
  # Wrapper for the MVI (Master Veteran Index) Service. vets.gov has access
  # to three MVI endpoints:
  # * PRPA_IN201301UV02 (TODO(AJD): Add Person)
  # * PRPA_IN201302UV02 (TODO(AJD): Update Person)
  # * PRPA_IN201305UV02 (aliased as .find_profile)
  class Service < Common::Client::Base
    # The MVI Service SOAP operations vets.gov has access to
    OPERATIONS = {
      add_person: 'PRPA_IN201301UV02',
      update_person: 'PRPA_IN201302UV02',
      find_profile: 'PRPA_IN201305UV02'
    }.freeze

    # @return [MVI::Configuration] the configuration for this service
    configuration MVI::Configuration

    # Given a user queries MVI and returns their VA profile.
    #
    # @param user [User] the user to query MVI for
    # @return [MVI::Responses::FindProfileResponse] the parsed response from MVI.
    def find_profile(user)
      raw_response = perform(:post, '', create_profile_message(user), soapaction: OPERATIONS[:find_profile])
      MVI::Responses::FindProfileResponse.with_parsed_response(raw_response)
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "MVI find_profile connection failed: #{e.message}"
      MVI::Responses::FindProfileResponse.with_server_error
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      Rails.logger.error "MVI find_profile error: #{e.message}"
      MVI::Responses::FindProfileResponse.with_server_error
    end

    private

    def create_profile_message(user)
      return message_icn(user) if user.mhv_icn.present? # from SAML::UserAttributes::MHV::BasicLOA3User
      raise Common::Exceptions::ValidationErrors, user unless user.valid?(:loa3_user)
      message_user_attributes(user)
    end

    def message_icn(user)
      MVI::Messages::FindProfileMessageIcn.new(user.mhv_icn).to_xml
    end

    def message_user_attributes(user)
      given_names = [user.first_name]
      given_names.push user.middle_name unless user.middle_name.nil?
      MVI::Messages::FindProfileMessage.new(
        given_names,
        user.last_name,
        user.birth_date,
        user.ssn,
        user.gender
      ).to_xml
    end
  end
end
