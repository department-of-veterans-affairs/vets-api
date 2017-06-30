# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class NameInput < Common::Base
    include ActiveModel::Validations

    attribute :first_name, String
    attribute :last_name, String
    attribute :maiden_name, String
    attribute :middle_name, String
    attribute :suffix, String

    # TODO: request that name length validations be set larger
    validates :last_name, :first_name, presence: true
    validates :last_name, :first_name, :middle_name, :maiden_name, length: { maximum: 15 }
    validates :suffix, length: { maximum: 3 }

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      hash = {
        first_name: first_name, last_name: last_name, maiden_name: maiden_name,
        middle_name: middle_name, suffix: suffix
      }

      [:maiden_name, :middle_name, :suffix].each { |key| hash.delete(key) if hash[key].nil? }
      hash
    end

    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
