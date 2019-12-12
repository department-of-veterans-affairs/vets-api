# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class CCEForm < Common::Form
    attribute :service_type, String

    validates :service_type, presence: true

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end
  end
end
