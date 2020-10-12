# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class LettersSerializer
      include FastJsonapi::ObjectSerializer
      set_type :letters
      attributes :letters, :full_name
    end
  end
end
