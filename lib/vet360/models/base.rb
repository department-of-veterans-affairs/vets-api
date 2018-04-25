# frozen_string_literal: true

require 'common/models/base'
require 'common/models/attribute_types/iso8601_time'

module Vet360
  module Models
    class Base
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      SOURCE_SYSTEM = 'VETSGOV'
    end
  end
end
