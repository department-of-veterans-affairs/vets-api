# frozen_string_literal: true

require 'common/exceptions/unprocessable_entity'

module MPI
  class OrchSearchService < Service
    configuration MPI::Configuration

    private

    def measure_info(user_identity)
      Rails.logger.measure_info(
        'Performed MVI Orchestrated Search Query', payload: logging_context(user_identity)
      ) { yield }
    end

    def create_profile_message(user, search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
      unless user.valid? && user.edipi.present?
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'User is invalid or missing edipi',
          source: 'OrchSearchService'
        )
      end

      message_user_attributes(user, search_type)
    end

    def message_user_attributes(user, search_type)
      given_names = [user.first_name]
      given_names.push user.middle_name unless user.middle_name.nil?
      profile = {
        given_names: given_names,
        last_name: user.last_name,
        birth_date: user.birth_date,
        ssn: user.ssn,
        gender: user.gender
      }
      MPI::Messages::FindProfileMessage.new(
        profile,
        orch_search: true,
        edipi: user.edipi,
        search_type: search_type
      ).to_xml
    end
  end
end
