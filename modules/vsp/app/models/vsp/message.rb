# frozen_string_literal: true
require 'dry-types'
require 'dry-struct'

module Vsp
  module Types
    include Dry::Types.module
  end

  class Message < Dry::Struct
    attribute :message, Types::String
  end
end
