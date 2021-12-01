# frozen_string_literal: true

require 'common/exceptions/unprocessable_entity'

module MPI
  class OrchSearchService < Service
    configuration MPI::Configuration

    private

    def measure_info(user_identity, &block)
      Rails.logger.measure_info(
        'Performed MVI Orchestrated Search Query', payload: logging_context(user_identity), &block
      )
    end

    def create_profile_message(user_identity, search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
      unless user_identity.valid? && user_identity.edipi.present?
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'User is invalid or missing edipi',
          source: 'OrchSearchService'
        )
      end

      message_user_attributes(user_identity, search_type)
    end

    def message_user_attributes(user_identity, search_type)
      given_names = [user_identity.first_name]
      given_names.push user_identity.middle_name unless user_identity.middle_name.nil?
      profile = {
        given_names: given_names,
        last_name: user_identity.last_name,
        birth_date: user_identity.birth_date,
        ssn: user_identity.ssn,
        gender: user_identity.gender
      }
      MPI::Messages::FindProfileMessage.new(
        profile,
        orch_search: true,
        edipi: user_identity.edipi,
        search_type: search_type
      ).to_xml
    end
  end
end
