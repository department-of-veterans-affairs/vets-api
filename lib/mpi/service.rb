# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require_relative 'configuration'
require 'mpi/messages/add_person_proxy_add_message'
require 'mpi/services/add_person_response_creator'
require 'mpi/messages/add_person_implicit_search_message'
require 'mpi/services/find_profile_response_creator'
require 'mpi/messages/find_profile_by_attributes'
require 'mpi/messages/find_profile_by_identifier'
require 'mpi/messages/find_profile_by_edipi'
require 'mpi/messages/find_profile_by_facility'
require 'mpi/messages/update_profile_message'
require 'mpi/responses/add_person_response'
require 'mpi/responses/find_profile_response'
require 'mpi/constants'

module MPI
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration MPI::Configuration

    STATSD_KEY_PREFIX = 'api.mvi'

    CONNECTION_ERRORS = [Faraday::ConnectionFailed,
                         Common::Client::Errors::ClientError,
                         Common::Exceptions::GatewayTimeout,
                         Breakers::OutageException].freeze

    # rubocop:disable Metrics/ParameterLists
    def add_person_proxy(last_name:, ssn:, birth_date:, icn:, edipi:, search_token:, first_name:, as_agent: false)
      with_monitoring do
        raw_response = perform(
          :post, '',
          MPI::Messages::AddPersonProxyAddMessage.new(last_name:,
                                                      ssn:,
                                                      birth_date:,
                                                      icn:,
                                                      edipi:,
                                                      search_token:,
                                                      first_name:,
                                                      as_agent:).perform,
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
          MPI::Messages::AddPersonImplicitSearchMessage.new(last_name:,
                                                            ssn:,
                                                            birth_date:,
                                                            email:,
                                                            address:,
                                                            idme_uuid:,
                                                            logingov_uuid:,
                                                            first_name:).perform,
          soapaction: Constants::ADD_PERSON
        )
        MPI::Services::AddPersonResponseCreator.new(type: Constants::ADD_PERSON_IMPLICIT_TYPE,
                                                    response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::AddPersonResponseCreator.new(type: Constants::ADD_PERSON_IMPLICIT_TYPE, error: e).perform
    end
    # rubocop:enable Metrics/ParameterLists

    def find_profile_by_identifier(identifier:,
                                   identifier_type:,
                                   search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA,
                                   view_type: Constants::PRIMARY_VIEW)
      with_monitoring do
        message = MPI::Messages::FindProfileByIdentifier.new(identifier:, identifier_type:, search_type:, view_type:)
        raw_response = perform(:post, '', message.perform, soapaction: Constants::FIND_PROFILE)

        MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_IDENTIFIER_TYPE,
                                                      response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_IDENTIFIER_TYPE, error: e).perform
    end

    def find_profile_by_edipi(edipi:, search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
      with_monitoring do
        raw_response = perform(:post, '',
                               MPI::Messages::FindProfileByEdipi.new(edipi:,
                                                                     search_type:).perform,
                               soapaction: Constants::FIND_PROFILE)
        MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_EDIPI_TYPE,
                                                      response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_EDIPI_TYPE, error: e).perform
    end

    def find_profile_by_facility(facility_id:, vista_id:, search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
      with_monitoring do
        raw_response = perform(:post, '',
                               MPI::Messages::FindProfileByFacility.new(facility_id:,
                                                                        vista_id:,
                                                                        search_type:).perform,
                               soapaction: Constants::FIND_PROFILE)
        MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_FACILITY_TYPE,
                                                      response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_FACILITY_TYPE, error: e).perform
    end

    def find_profile_by_attributes_with_orch_search(first_name:,
                                                    last_name:,
                                                    birth_date:,
                                                    ssn:,
                                                    edipi:)
      with_monitoring do
        raw_response = perform(:post, '',
                               MPI::Messages::FindProfileByAttributes.new(first_name:,
                                                                          last_name:,
                                                                          birth_date:,
                                                                          ssn:,
                                                                          orch_search: true,
                                                                          edipi:).perform,
                               soapaction: Constants::FIND_PROFILE)
        MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_ATTRIBUTES_ORCH_SEARCH_TYPE,
                                                      response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_ATTRIBUTES_ORCH_SEARCH_TYPE,
                                                    error: e).perform
    end

    def find_profile_by_attributes(first_name:,
                                   last_name:,
                                   birth_date:,
                                   ssn:,
                                   search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
      with_monitoring do
        raw_response = perform(:post, '',
                               MPI::Messages::FindProfileByAttributes.new(first_name:,
                                                                          last_name:,
                                                                          birth_date:,
                                                                          ssn:,
                                                                          search_type:).perform,
                               soapaction: Constants::FIND_PROFILE)
        MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_ATTRIBUTES_TYPE,
                                                      response: raw_response).perform
      end
    rescue *CONNECTION_ERRORS => e
      MPI::Services::FindProfileResponseCreator.new(type: Constants::FIND_PROFILE_BY_ATTRIBUTES_TYPE, error: e).perform
    end

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
          MPI::Messages::UpdateProfileMessage.new(last_name:,
                                                  ssn:,
                                                  birth_date:,
                                                  icn:,
                                                  email:,
                                                  address:,
                                                  idme_uuid:,
                                                  logingov_uuid:,
                                                  edipi:,
                                                  first_name:).perform,
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
  end
end
