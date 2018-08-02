# frozen_string_literal: true

require 'common/models/base'

module IHub
  module Models
    class Base
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)
    end
  end
end
