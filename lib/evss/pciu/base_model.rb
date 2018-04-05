# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PCIU
    class BaseModel
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)
    end
  end
end
