# frozen_string_literal: true

require 'common/client/base'
require 'mvi/configuration'
require 'mvi/responses/find_profile_response'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'mvi/errors/errors'
require 'sentry_logging'

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
      log_message_to_sentry("MVI find_profile connection failed: #{e.message}", :error)
      MVI::Responses::FindProfileResponse.with_server_error
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI find_profile error: #{e.message}", :error)
      MVI::Responses::FindProfileResponse.with_server_error
    rescue MVI::Errors::Base => e
      mvi_error_handler(user, e)
      if e.is_a?(MVI::Errors::RecordNotFound)
        MVI::Responses::FindProfileResponse.with_not_found
      else
        MVI::Responses::FindProfileResponse.with_server_error
      end
    end

    def find_historical_icns(user)
      return [] unless user.loa3?

      raw_response = perform(
        :post,
        '',
        create_profile_message(user, historical_icns: true),
        soapaction: OPERATIONS[:find_profile]
      )

      MVI::Responses::HistoricalIcnParser.new(raw_response.body).get_icns
    end

    private

    # TODO: Possibly consider adding Grafana Instrumentation here too
    def mvi_error_handler(user, e)
      case e
      when MVI::Errors::DuplicateRecords
        log_message_to_sentry('MVI Duplicate Record', :warn)
      when MVI::Errors::RecordNotFound
        # Not going to log RecordNotFound
        # NOTE: ICN based lookups do not return RecordNotFound. They return InvalidRequestError
        # log_message_to_sentry('MVI Record Not Found', :warn)
        nil
      when MVI::Errors::InvalidRequestError
        if user.mhv_icn.present?
          log_message_to_sentry('MVI Invalid Request (Possible RecordNotFound)', :error)
        else
          log_message_to_sentry('MVI Invalid Request', :error)
        end
      when MVI::Errors::FailedRequestError
        log_message_to_sentry('MVI Failed Request', :error)
      end
    end

    def create_profile_message(user, opt = {})
      return message_icn(user, opt) if user.mhv_icn.present? # from SAML::UserAttributes::MHV::BasicLOA3User
      raise Common::Exceptions::ValidationErrors, user unless user.valid?(:loa3_user)
      message_user_attributes(user, opt)
    end

    def message_icn(user, opt)
      message_with_options(MVI::Messages::FindProfileMessageIcn.new(user.mhv_icn), opt).to_xml
    end

    def message_user_attributes(user, opt)
      given_names = [user.first_name]
      given_names.push user.middle_name unless user.middle_name.nil?
      message_with_options(
        MVI::Messages::FindProfileMessage.new(
          given_names,
          user.last_name,
          user.birth_date,
          user.ssn,
          user.gender
        ), opt).to_xml
    end

    def message_with_options(message, opt)
      message.modify_code = "MVI.COMP#{opt[:historical_icns] ? '2' : '1'}"
      message
    end
  end
end
