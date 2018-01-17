# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class FullName < Preneeds::Base
    attribute :first, String
    attribute :last, String
    attribute :maiden, String
    attribute :middle, String
    attribute :suffix, String

    # Hash attributes must correspond to xsd ordering or API call will fail
    def as_eoas
      hash = {
        firstName: first, lastName: last, maidenName: maiden,
        middleName: middle, suffix: suffix
      }

      %i[maidenName middleName suffix].each { |key| hash.delete(key) if hash[key].blank? }
      hash
    end

    def self.permitted_params
      %i[first last maiden middle suffix]
    end
  end
end
