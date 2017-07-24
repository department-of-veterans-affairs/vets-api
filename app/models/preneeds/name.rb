# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class Name < Preneeds::Base
    attribute :first_name, String
    attribute :last_name, String
    attribute :maiden_name, String
    attribute :middle_name, String
    attribute :suffix, String

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      hash = {
        firstName: first_name, lastName: last_name, maidenName: maiden_name,
        middleName: middle_name, suffix: suffix
      }

      [:maiden_name, :middle_name, :suffix].each { |key| hash.delete(key) if hash[key].nil? }
      hash
    end

    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
