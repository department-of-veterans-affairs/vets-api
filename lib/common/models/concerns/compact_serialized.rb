# frozen_string_literal: true
module Common
  module CompactSerialized
    extend ActiveSupport::Concern

    def as_json(options = {})
      super(options).compact
    end
  end
end
