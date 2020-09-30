# frozen_string_literal: true

module HealthQuest
  module V0
    class PGDQuesResponseSerializer
      include FastJsonapi::ObjectSerializer

      set_type :questionnaire_response

      attributes :text
    end
  end
end
