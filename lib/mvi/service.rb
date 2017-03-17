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
  #
  # = Usage
  # Calls endpoints as class methods, if successful it will return a ruby hash of the SOAP XML response.
  #
  # Example:
  #  birth_date = '1980-1-1'
  #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', birth_date, '555-44-3333').to_xml
  #  response = MVI::Service.new.find_profile(message)
  #
  class Service < Common::Client::Base
    OPERATIONS = {
      add_person: 'PRPA_IN201301UV02',
      update_person: 'PRPA_IN201302UV02',
      find_profile: 'PRPA_IN201305UV02'
    }.freeze

    configuration MVI::Configuration

    def find_profile(user)
      return MVI::Responses::FindProfileResponse.with_not_authorized unless user.loa3?
      raw_response = perform(:post, '', create_profile_message(user), soapaction: OPERATIONS[:find_profile])
      MVI::Responses::FindProfileResponse.with_parsed_response(raw_response)
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "MVI find_profile connection failed: #{e.message}"
      MVI::Responses::FindProfileResponse.with_server_error
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "MVI find_profile error: #{e.message}"
      MVI::Responses::FindProfileResponse.with_server_error
    end

    private

    def create_profile_message(user)
      puts user.inspect
      raise Common::Exceptions::ValidationErrors, user unless user.valid?(:loa3_user)
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
