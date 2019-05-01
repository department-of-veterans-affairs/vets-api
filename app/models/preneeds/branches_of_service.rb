# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models a branch of service from the EOAS service.
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute code
  #   @return [String] branch of service abbreviated code
  # @!attribute flat_full_descr
  #   @return [String] flat full description
  # @!attribute full_descr
  #   @return [String] full description
  # @!attribute short_descr
  #   @return [String] short description
  # @!attribute upright_full_descr
  #   @return [String] upright full description
  # @!attribute begin_date
  #   @return [Common::UTCTime] begin date of branch of service
  # @!attribute end_date
  #   @return [Common::UTCTime] end date of branch of service
  # @!attribute state_required
  #   @return [Boolean] 'Y' or 'N'; state required for this branch of service.
  #
  class BranchesOfService < Common::Base
    attribute :code, String
    attribute :flat_full_descr, String
    attribute :full_descr, String
    attribute :short_descr, String
    attribute :upright_full_descr, String

    attribute :begin_date, Common::UTCTime
    attribute :end_date, Common::UTCTime
    attribute :state_required, String

    # Alias for #code attribute
    #
    # @return [String] branch of service abbreviated code
    #
    def id
      code
    end

    # Sort operator
    # Default sort should be by full_descr ascending
    #
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      full_descr <=> other.full_descr
    end
  end
end
