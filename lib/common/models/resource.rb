# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

module Types
  include Dry::Types.module
end

module Common
  class Resource < Dry::Struct
  end
end
