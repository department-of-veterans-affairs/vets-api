# frozen_string_literal: true

require 'active_model'
require 'common/models/attribute_types/utc_time'

module Common
  class Form
    extend ActiveModel::Naming
    include ActiveModel::Validations
    include Virtus.model(nullify_blank: true)
  end
end
