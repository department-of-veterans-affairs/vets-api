# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class NameInput < Common::Base
    include ActiveModel::Validations

    # Removed length validation on names: bad xsd validation
    validates :last_name, :first_name, presence: true
    validates :suffix, length: { maximum: 3 }

    attribute :first_name, String
    attribute :last_name, String
    attribute :maiden_name, String
    attribute :middle_name, String
    attribute :suffix, String

    def message
      hash = {
        first_name: first_name, last_name: last_name, maiden_name: maiden_name,
        middle_name: middle_name, suffix: suffix
      }

      [:maiden_name, :middle_name, :suffix].each { |key| hash.delete(key) if hash[key].nil? }
      hash
    end
  end
end
