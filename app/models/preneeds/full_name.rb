# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models a full name for persons included in a {Preneeds::BurialForm} form
  #
  # @!attribute first
  #   @return [String] first name
  # @!attribute last
  #   @return [String] last name
  # @!attribute maiden
  #   @return [String] maiden name
  # @!attribute middle
  #   @return [String] middle name
  # @!attribute suffix
  #   @return [String] name suffix
  #
  class FullName < Preneeds::Base
    attribute :first, String
    attribute :last, String
    attribute :maiden, String
    attribute :middle, String
    attribute :suffix, String

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      hash = {
        firstName: first, lastName: last, maidenName: maiden,
        middleName: middle, suffix:
      }

      %i[maidenName middleName suffix].each { |key| hash.delete(key) if hash[key].blank? }
      hash
    end

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      %i[first last maiden middle suffix]
    end
  end
end
