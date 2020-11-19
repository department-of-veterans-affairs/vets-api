# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      class Factory
        attr_reader :session_service, :user, :map_query

        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @user = user
          @session_service = HealthQuest::SessionService.new(user)
          @map_query = PatientGeneratedData::QuestionnaireResponse::MapQuery.build(session_service.headers)
        end

        def search
          map_query.search(author: user.icn)
        end
      end
    end
  end
end
