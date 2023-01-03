# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'sentry_logging'
require_relative 'configuration'
require 'mpi/errors/errors'
require 'mpi/messages/add_person_proxy_add_message'
require 'mpi/services/add_person_response_creator'
require 'mpi/messages/add_person_implicit_search_message'
require 'mpi/messages/find_profile_by_attributes'
require 'mpi/messages/find_profile_by_identifier'
require 'mpi/messages/find_profile_by_edipi'
require 'mpi/messages/update_profile_message'
require 'mpi/responses/add_person_response'
require 'mpi/responses/find_profile_response'
require 'mpi/constants'

module MPI
  # Wrapper for the MVI (Master Veteran Index) Service.
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    # @return [MPI::Configuration] the configuration for this service
    configuration MPI::Configuration

    STATSD_KEY_PREFIX = 'api.mvi'

    CONNECTION_ERRORS = [Faraday::ConnectionFailed,
                         Common::Client::Errors::ClientError,
                         Common::Exceptions::GatewayTimeout,
                         Breakers::OutageException].freeze
    SERVER_ERROR = 'server_error'

    # rubocop:disable Metrics/ParameterLists
    def add_person_proxy(last_name:, ssn:, birth_date:, icn:, edipi:, search_token:, first_name:)
      with_monitoring do
        raw_response = perform(
          :post, '',
          MPI::Messages::AddPersonProxyAddMessage.new(last_name: last_name,
                                                      ssn: ssn,
                                                      birth_date: birth_date,
                                                      icn: icn,
                                                      edipi: edipi,
                                                      search_token: search_token,
                                                      first_name: first_name).perform,
          soapaction: Constants::ADD_PERSON
        )
        MPI::Services::AddPersonResponseCreator.new(type: Constants::ADD_PERSON_PROXY_TYPE,
                                                    response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::AddPersonResponseCreator.new(type: Constants::ADD_PERSON_PROXY_TYPE, error: e).perform
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/ParameterLists
    def add_person_implicit_search(first_name:,
                                   last_name:,
                                   ssn:,
                                   birth_date:,
                                   email: nil,
                                   address: nil,
                                   idme_uuid: nil,
                                   logingov_uuid: nil)
      with_monitoring do
        raw_response = perform(
          :post, '',
          MPI::Messages::AddPersonImplicitSearchMessage.new(last_name: last_name,
                                                            ssn: ssn,
                                                            birth_date: birth_date,
                                                            email: email,
                                                            address: address,
                                                            idme_uuid: idme_uuid,
                                                            logingov_uuid: logingov_uuid,
                                                            first_name: first_name).perform,
          soapaction: Constants::ADD_PERSON
        )
        MPI::Services::AddPersonResponseCreator.new(type: Constants::ADD_PERSON_IMPLICIT_TYPE,
                                                    response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::AddPersonResponseCreator.new(type: Constants::ADD_PERSON_IMPLICIT_TYPE, error: e).perform
    end
    # rubocop:enable Metrics/ParameterLists

    # Given a user queries MVI and returns their VA profile.
    #
    # @param user [UserIdentity] the user to query MVI for
    # @return [MPI::Responses::FindProfileResponse] the parsed response from MVI.
    # rubocop:disable Metrics/MethodLength
    def find_profile(user_identity,
                     search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA,
                     orch_search: false)
      profile_message = create_profile_message(user_identity, search_type: search_type, orch_search: orch_search)
      with_monitoring do
        raw_response = perform(:post, '', profile_message, soapaction: Constants::FIND_PROFILE)
        MPI::Responses::FindProfileResponse.with_parsed_response(raw_response)
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI find_profile connection failed.', :warn)
      mvi_profile_exception_response_for(Constants::OUTAGE_EXCEPTION, e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI find_profile connection failed: #{e.message}", :warn)
      mvi_profile_exception_response_for(Constants::CONNECTION_FAILED, e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI find_profile error: #{e.message}", :warn)
      mvi_profile_exception_response_for(Constants::CONNECTION_FAILED, e)
    rescue MPI::Errors::Response, MPI::Errors::Request => e
      mvi_error_handler(e, 'find_profile', profile_message)
      if e.is_a?(MPI::Errors::RecordNotFound) || e.is_a?(MPI::Errors::DuplicateRecords)
        mvi_profile_exception_response_for(Constants::NOT_FOUND, e, type: 'not_found')
      else
        mvi_profile_exception_response_for(Constants::ERROR, e)
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/ParameterLists
    def update_profile(last_name:,
                       ssn:,
                       birth_date:,
                       icn:,
                       email:,
                       address:,
                       idme_uuid:,
                       logingov_uuid:,
                       edipi:,
                       first_name:)
      with_monitoring do
        raw_response = perform(
          :post, '',
          MPI::Messages::UpdateProfileMessage.new(last_name: last_name,
                                                  ssn: ssn,
                                                  birth_date: birth_date,
                                                  icn: icn,
                                                  email: email,
                                                  address: address,
                                                  idme_uuid: idme_uuid,
                                                  logingov_uuid: logingov_uuid,
                                                  edipi: edipi,
                                                  first_name: first_name).perform,
          soapaction: Constants::UPDATE_PROFILE
        )
        MPI::Services::AddPersonResponseCreator.new(type: Constants::UPDATE_PROFILE_TYPE,
                                                    response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::AddPersonResponseCreator.new(type: Constants::UPDATE_PROFILE_TYPE, error: e).perform
    end
    # rubocop:enable Metrics/ParameterLists

    def self.service_is_up?
      last_mvi_outage = Breakers::Outage.find_latest(service: MPI::Configuration.instance.breakers_service)
      last_mvi_outage.blank? || last_mvi_outage.end_time.present?
    end

    private

    def mvi_profile_exception_response_for(key, error, type: SERVER_ERROR)
      exception = build_exception(key, error)

      if type == SERVER_ERROR
        MPI::Responses::FindProfileResponse.with_server_error(exception)
      else
        MPI::Responses::FindProfileResponse.with_not_found(exception)
      end
    end

    def build_exception(key, error)
      Common::Exceptions::BackendServiceException.new(
        key,
        { source: self.class },
        error.try(:status),
        error.try(:body)
      )
    end

    def mvi_error_handler(error, source = '', request = '')
      context = { error: error.try(:body) }
      case error
      when MPI::Errors::DuplicateRecords
        log_exception_to_sentry(error, nil, nil, 'warn')
      when MPI::Errors::RecordNotFound
        Rails.logger.info('MVI Record Not Found')
      when MPI::Errors::InvalidRequestError
        context[:request] = request
        log_exception_to_sentry(error, context, { message: 'MVI Invalid Request', source: source })
      when MPI::Errors::FailedRequestError
        log_exception_to_sentry(error, context)
      end
    end

    def create_profile_message(user_identity,
                               search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA,
                               orch_search: false)
      if orch_search == true
        if user_identity.edipi.blank?
          raise Common::Exceptions::UnprocessableEntity.new(detail: 'User is missing EDIPI',
                                                            source: 'MPI Service')
        end

        return message_user_attributes(user_identity, search_type, orch_search: orch_search)
      end
      return message_icn(user_identity, search_type) if user_identity.mhv_icn.present?
      return message_edipi(user_identity, search_type) if user_identity.edipi.present?
      if user_identity.logingov_uuid.present?
        return message_identifier(user_identity.logingov_uuid, 'logingov', search_type)
      end
      return message_identifier(user_identity.idme_uuid, 'idme', search_type) if user_identity.idme_uuid.present?

      message_user_attributes(user_identity, search_type)
    end

    def message_icn(user_identity, search_type)
      Raven.tags_context(mvi_find_profile: 'icn')
      MPI::Messages::FindProfileByIdentifier.new(identifier: user_identity.mhv_icn, search_type: search_type).perform
    end

    def message_identifier(identifier, identifier_type, search_type)
      Raven.tags_context(mvi_find_profile: identifier_type)

      identifier_constant = case identifier_type
                            when 'idme'
                              Constants::IDME_IDENTIFIER
                            when 'logingov'
                              Constants::LOGINGOV_IDENTIFIER
                            end
      correlation_identifier = "#{identifier}^PN^#{identifier_constant}^USDVA^A"
      MPI::Messages::FindProfileByIdentifier.new(identifier: correlation_identifier, search_type: search_type).perform
    end

    def message_edipi(user_identity, search_type)
      Raven.tags_context(mvi_find_profile: 'edipi')
      MPI::Messages::FindProfileByEdipi.new(edipi: user_identity.edipi, search_type: search_type).perform
    end

    def message_user_attributes(user_identity, search_type, orch_search: false)
      raise Common::Exceptions::ValidationErrors, user_identity unless user_identity.valid?

      Raven.tags_context(mvi_find_profile: 'user_attributes')

      given_names = [user_identity.first_name]
      given_names.push user_identity.middle_name unless user_identity.middle_name.nil?
      profile = {
        given_names: given_names,
        last_name: user_identity.last_name,
        birth_date: user_identity.birth_date,
        ssn: user_identity.ssn
      }
      MPI::Messages::FindProfileByAttributes.new(
        profile: profile,
        search_type: search_type,
        orch_search: orch_search,
        edipi: orch_search == true ? user_identity.edipi : nil
      ).perform
    end
  end
end
