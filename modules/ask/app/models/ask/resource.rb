# frozen_string_literal: true

require 'common/models/resource'

module Ask
  class Resource < Common::Resource
    attribute :id, Types::Nil.default(nil)
    attribute :message, Types::String
  end
end
