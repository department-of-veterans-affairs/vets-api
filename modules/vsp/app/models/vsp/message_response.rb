# frozen_string_literal: true

require 'common/models/resource'

module Vsp
  class MessageResponse < Common::Resource
    attribute :id, Types::Nil.default(nil)
    attribute :message, Types::String
  end
end
