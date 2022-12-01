# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'sentry_logging'
require_relative 'configuration'
require 'mpi/errors/errors'
require 'mpi/messages/add_person_proxy_add_message'
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

    STATSD_KEY_PREFIX = 'api.mvi' unless const_defined?(:STATSD_KEY_PREFIX)
    SERVER_ERROR = 'server_error'

    # rubocop:disable Metrics/MethodLength
    def add_person_proxy(user_identity)
      with_monitoring do
        measure_info(user_identity) do
          raw_response = perform(
            :post, '',
            create_add_person_proxy_message(user_identity),
            soapaction: MPI::Constants::ADD_PERSON
          )
          MPI::Responses::AddPersonResponse.with_parsed_response('add_person_proxy', raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI add_person_proxy connection failed.', :warn)
      mvi_add_exception_response_for(MPI::Constants::OUTAGE_EXCEPTION, e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI add_person_proxy connection failed: #{e.message}", :warn)
      mvi_add_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI add_person_proxy error: #{e.message}", :warn)
      mvi_add_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue MPI::Errors::Base => e
      key = get_mvi_error_key(e)
      mvi_error_handler(e, 'add_person_proxy')
      mvi_add_exception_response_for(key, e)
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def add_person_implicit_search(user_identity)
      with_monitoring do
        measure_info(user_identity) do
          raw_response = perform(
            :post, '',
            create_add_person_implicit_search_message(user_identity),
            soapaction: MPI::Constants::ADD_PERSON
          )
          MPI::Responses::AddPersonResponse.with_parsed_response('add_person_implicit_search', raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI add_person_implicit connection failed.', :warn)
      mvi_add_exception_response_for(MPI::Constants::OUTAGE_EXCEPTION, e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI add_person_implicit connection failed: #{e.message}", :warn)
      mvi_add_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI add_person_implicit error: #{e.message}", :warn)
      mvi_add_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue MPI::Errors::Base => e
      key = get_mvi_error_key(e)
      mvi_error_handler(e, 'add_person_implicit')
      mvi_add_exception_response_for(key, e)
    end
    # rubocop:enable Metrics/MethodLength

    # Given a user queries MVI and returns their VA profile.
    #
    # @param user [UserIdentity] the user to query MVI for
    # @return [MPI::Responses::FindProfileResponse] the parsed response from MVI.
    # rubocop:disable Metrics/MethodLength
    def find_profile(user_identity,
                     search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA,
                     orch_search: false)
      profile_message = create_profile_message(user_identity, search_type: search_type, orch_search: orch_search)
      with_monitoring do
        measure_info(user_identity) do
          raw_response = perform(
            :post, '',
            profile_message,
            soapaction: MPI::Constants::FIND_PROFILE
          )
          MPI::Responses::FindProfileResponse.with_parsed_response(raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI find_profile connection failed.', :warn)
      mvi_profile_exception_response_for(MPI::Constants::OUTAGE_EXCEPTION, e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI find_profile connection failed: #{e.message}", :warn)
      mvi_profile_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI find_profile error: #{e.message}", :warn)
      mvi_profile_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue MPI::Errors::Base => e
      mvi_error_handler(e, 'find_profile', profile_message)
      if e.is_a?(MPI::Errors::RecordNotFound)
        mvi_profile_exception_response_for(MPI::Constants::NOT_FOUND, e, type: 'not_found')
      else
        mvi_profile_exception_response_for(MPI::Constants::ERROR, e)
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def update_profile(user_identity)
      with_monitoring do
        measure_info(user_identity) do
          raw_response = perform(
            :post, '',
            create_update_profile_message(user_identity),
            soapaction: MPI::Constants::UPDATE_PROFILE
          )
          MPI::Responses::AddPersonResponse.with_parsed_response('update_profile', raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI update_profile connection failed.', :warn)
      mvi_add_exception_response_for(MPI::Constants::OUTAGE_EXCEPTION, e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI update_profile connection failed: #{e.message}", :warn)
      mvi_add_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI update_profile error: #{e.message}", :warn)
      mvi_add_exception_response_for(MPI::Constants::CONNECTION_FAILED, e)
    rescue Errors::ArgumentError => e
      log_message_to_sentry("MVI update_profile request error: #{e.message}", :warn)
      nil
    rescue MPI::Errors::Base => e
      key = get_mvi_error_key(e)
      mvi_error_handler(e, 'update_profile')
      mvi_add_exception_response_for(key, e)
    end
    # rubocop:enable Metrics/MethodLength

    def self.service_is_up?
      last_mvi_outage = Breakers::Outage.find_latest(service: MPI::Configuration.instance.breakers_service)
      last_mvi_outage.blank? || last_mvi_outage.end_time.present?
    end

    private

    def measure_info(user_identity, &block)
      Rails.logger.measure_info('Performed MVI Query', payload: logging_context(user_identity), &block)
    end

    def get_mvi_error_key(e)
      error_name = e.try(:body)&.[](:other)&.first&.[](:displayName)
      return MPI::Constants::DUPLICATE_ERROR if error_name == 'Duplicate Key Identifier'

      MPI::Constants::ERROR
    end

    def mvi_add_exception_response_for(key, error)
      exception = build_exception(key, error)

      MPI::Responses::AddPersonResponse.with_server_error(exception)
    end

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

    def logging_context(user_identity)
      {
        uuid: user_identity.uuid,
        authn_context: user_identity.authn_context
      }
    end

    def create_add_person_implicit_search_message(user_identity)
      raise Common::Exceptions::ValidationErrors, user_identity unless user_identity.valid?

      MPI::Messages::AddPersonImplicitSearchMessage.new(last_name: user_identity.last_name,
                                                        ssn: user_identity.ssn,
                                                        birth_date: user_identity.birth_date,
                                                        email: user_identity.email,
                                                        address: user_identity.address,
                                                        idme_uuid: user_identity.idme_uuid,
                                                        logingov_uuid: user_identity.logingov_uuid,
                                                        first_name: user_identity.first_name).perform
    end

    def create_add_person_proxy_message(user_identity)
      raise Common::Exceptions::ValidationErrors, user_identity unless user_identity.valid?
      return if user_identity.icn_with_aaid.blank?

      MPI::Messages::AddPersonProxyAddMessage.new(last_name: user_identity.last_name,
                                                  ssn: user_identity.ssn,
                                                  birth_date: user_identity.birth_date,
                                                  icn: user_identity.icn,
                                                  edipi: user_identity.edipi,
                                                  search_token: user_identity.search_token,
                                                  first_name: user_identity.first_name).perform
    end

    def create_update_profile_message(user_identity)
      raise Common::Exceptions::ValidationErrors, user_identity unless user_identity.valid?

      MPI::Messages::UpdateProfileMessage.new(last_name: user_identity.last_name,
                                              ssn: user_identity.ssn,
                                              birth_date: user_identity.birth_date,
                                              icn: user_identity.icn,
                                              email: user_identity.email,
                                              address: user_identity.address,
                                              idme_uuid: user_identity.idme_uuid,
                                              logingov_uuid: user_identity.logingov_uuid,
                                              edipi: user_identity.edipi,
                                              first_name: user_identity.first_name).perform
    end

    def create_profile_message(user_identity,
                               search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA,
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
