# frozen_string_literal: true

require 'common/models/form'

module MHVAC
  class UpgradeForm < Common::Form
    include ActiveModel::Validations

    attribute :user_id, Integer
    validates :user_id, presence: true

    def mhv_params
      raise Common::Exceptions::ValidationErrors, self unless valid?
      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end
  end
end
