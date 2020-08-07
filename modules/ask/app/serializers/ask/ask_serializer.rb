# frozen_string_literal: true

require 'fast_jsonapi'

module Ask
  class AskSerializer
    include FastJsonapi::ObjectSerializer
    attributes :message
  end
end
