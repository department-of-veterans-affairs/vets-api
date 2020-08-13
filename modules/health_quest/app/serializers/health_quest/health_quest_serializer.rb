# frozen_string_literal: true

require 'fast_jsonapi'

module HealthQuest
  class HealthQuestSerializer
    include FastJsonapi::ObjectSerializer
    attributes :message
  end
end
