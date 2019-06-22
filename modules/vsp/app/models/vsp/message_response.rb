# frozen_string_literal: true
require 'common/models/resource'

module Vsp
  class MessageResponse < Common::Resource
    attribute :message, Types::String
  end
end
