# frozen_string_literal: true

require 'forwardable'

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      class Factory
        extend Forwardable

        attr_reader :session_service, :user, :map_query, :options_builder

        def_delegator :@map_query, :get

        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @user = user
          @session_service = HealthQuest::SessionService.new(user)
          @map_query = PatientGeneratedData::QuestionnaireResponse::MapQuery.build(session_service.headers)
          @options_builder = OptionsBuilder
        end

        def search(filters)
          with_options = options_builder.manufacture(user, filters).to_hash

          map_query.search(with_options)
        end
      end
    end
  end
end
