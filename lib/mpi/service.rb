# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'sentry_logging'
require_relative 'configuration'
require 'mpi/errors/errors'
require 'mpi/messages/add_person_message'
require 'mpi/messages/find_profile_message'
require 'mpi/messages/find_profile_message_icn'
require 'mpi/messages/find_profile_message_edipi'
require 'mpi/responses/add_person_response'
require 'mpi/responses/find_profile_response'

module MPI
  # Wrapper for the MVI (Master Veteran Index) Service. vets.gov has access
  # to three MVI endpoints:
  # * PRPA_IN201301UV02 (TODO(AJD): Add Person)
  # * PRPA_IN201302UV02 (TODO(AJD): Update Person)
  # * PRPA_IN201305UV02 (aliased as .find_profile)
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    # The MVI Service SOAP operations vets.gov has access to
    unless const_defined?(:OPERATIONS)
      OPERATIONS = {
        add_person: 'PRPA_IN201301UV02',
        update_person: 'PRPA_IN201302UV02',
        find_profile: 'PRPA_IN201305UV02'
      }.freeze
    end

    # @return [MPI::Configuration] the configuration for this service
    configuration MPI::Configuration

    STATSD_KEY_PREFIX = 'api.mvi' unless const_defined?(:STATSD_KEY_PREFIX)
    SERVER_ERROR = 'server_error'

    # rubocop:disable Metrics/MethodLength
    def add_person(user_identity)
      with_monitoring do
        measure_info(user_identity) do
          raw_response = perform(
            :post, '',
            create_add_message(user_identity),
            soapaction: OPERATIONS[:add_person]
          )
          MPI::Responses::AddPersonResponse.with_parsed_response(raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI add_person connection failed.', :warn)
      mvi_add_exception_response_for('MVI_503', e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI add_person connection failed: #{e.message}", :warn)
      mvi_add_exception_response_for('MVI_504', e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI add_person error: #{e.message}", :warn)
      mvi_add_exception_response_for('MVI_504', e)
    rescue MPI::Errors::Base => e
      key = get_mvi_error_key(e)
      mvi_error_handler(user_identity, e, 'add_person')
      mvi_add_exception_response_for(key, e)
    end
    # rubocop:enable Metrics/MethodLength

    # Given a user queries MVI and returns their VA profile.
    #
    # @param user [UserIdentity] the user to query MVI for
    # @return [MPI::Responses::FindProfileResponse] the parsed response from MVI.
    # rubocop:disable Metrics/MethodLength
    def find_profile(user_identity)
      profile_message = create_profile_message(user_identity)
      with_monitoring do
        measure_info(user_identity) do
          raw_response = perform(
            :post, '',
            profile_message,
            soapaction: OPERATIONS[:find_profile]
          )
          MPI::Responses::FindProfileResponse.with_parsed_response(raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_message_to_sentry('MVI find_profile connection failed.', :warn)
      mvi_profile_exception_response_for('MVI_503', e)
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("MVI find_profile connection failed: #{e.message}", :warn)
      mvi_profile_exception_response_for('MVI_504', e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("MVI find_profile error: #{e.message}", :warn)
      mvi_profile_exception_response_for('MVI_504', e)
    rescue MPI::Errors::Base => e
      mvi_error_handler(user_identity, e, 'find_profile', profile_message)
      if e.is_a?(MPI::Errors::RecordNotFound)
        mvi_profile_exception_response_for('MVI_404', e, type: 'not_found')
      else
        mvi_profile_exception_response_for('MVI_502', e)
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.service_is_up?
      last_mvi_outage = Breakers::Outage.find_latest(service: MPI::Configuration.instance.breakers_service)
      last_mvi_outage.blank? || last_mvi_outage.end_time.present?
    end

    private

    def measure_info(user_identity)
      Rails.logger.measure_info('Performed MVI Query', payload: logging_context(user_identity)) { yield }
    end

    def get_mvi_error_key(e)
      error_name = e.body&.[](:other)&.first&.[](:displayName)
      return 'MVI_502_DUP' if error_name == 'Duplicate Key Identifier'

      'MVI_502'
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

    def mvi_error_handler(user_identity, error, source = '', request = '')
      case error
      when MPI::Errors::DuplicateRecords
        log_exception_to_sentry(error, nil, nil, 'warn')
      when MPI::Errors::RecordNotFound
        Rails.logger.info('MVI Record Not Found')
      when MPI::Errors::InvalidRequestError
        # NOTE: ICN based lookups do not return RecordNotFound. They return InvalidRequestError
        if user_identity.mhv_icn.present?
          log_exception_to_sentry(error, {}, { message: 'Possible RecordNotFound', source: source })
        else
          log_exception_to_sentry(error, { request: request }, { message: 'MVI Invalid Request', source: source })
        end
      when MPI::Errors::FailedRequestError
        log_exception_to_sentry(error)
      end
    end

    def logging_context(user_identity)
      {
        uuid: user_identity.uuid,
        authn_context: user_identity.authn_context
      }
    end

    def create_add_message(user)
      raise Common::Exceptions::ValidationErrors, user unless user.valid?

      MPI::Messages::AddPersonMessage.new(user).to_xml if user.icn_with_aaid.present?
    end

    # rubocop:disable Layout/LineLength
    def create_profile_message(user_identity)
      return message_icn(user_identity) if user_identity.mhv_icn.present? # from SAML::UserAttributes::MHV::BasicLOA3User
      return message_edipi(user_identity) if user_identity.dslogon_edipi.present? && Settings.mvi.edipi_search
      raise Common::Exceptions::ValidationErrors, user_identity unless user_identity.valid?

      message_user_attributes(user_identity)
    end
    # rubocop:enable Layout/LineLength

    def message_icn(user)
      Raven.tags_context(mvi_find_profile: 'icn')
      MPI::Messages::FindProfileMessageIcn.new(user.mhv_icn).to_xml
    end

    def message_edipi(user)
      Raven.tags_context(mvi_find_profile: 'edipi')
      MPI::Messages::FindProfileMessageEdipi.new(user.dslogon_edipi).to_xml
    end

    def message_user_attributes(user)
      Raven.tags_context(mvi_find_profile: 'user_attributes')
      given_names = [user.first_name]
      given_names.push user.middle_name unless user.middle_name.nil?
      profile = {
        given_names: given_names,
        last_name: user.last_name,
        birth_date: user.birth_date,
        ssn: user.ssn,
        gender: user.gender
      }
      MPI::Messages::FindProfileMessage.new(profile).to_xml
    end
  end
end
