# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models a military rank from the EOAS service.
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute branch_of_service_cd
  #   @return [String] brach of service abbreviated code
  # @!attribute military_rank_detail
  #   @return [MilitaryRankDetail] rank details object
  # @!attribute activated_one_date
  #   @return [Common::UTCTime] activated date one
  # @!attribute activated_two_date
  #   @return [Common::UTCTime] activated date two
  # @!attribute activated_three_date
  #   @return [Common::UTCTime] activated date three
  # @!attribute deactivated_one_date
  #   @return [Common::UTCTime] deactivated date one
  # @!attribute deactivated_two_date
  #   @return [Common::UTCTime] deactivated date two
  # @!attribute deactivated_three_date
  #   @return [Common::UTCTime] deactivated date three
  #
  class MilitaryRank < Common::Base
    attribute :branch_of_service_cd, String
    attribute :military_rank_detail, MilitaryRankDetail

    attribute :activated_one_date, Common::UTCTime
    attribute :activated_two_date, Common::UTCTime
    attribute :activated_three_date, Common::UTCTime
    attribute :deactivated_one_date, Common::UTCTime
    attribute :deactivated_two_date, Common::UTCTime
    attribute :deactivated_three_date, Common::UTCTime

    # return [String] branch of service code and rank code joined with ':'
    #
    def id
      branch_of_service_cd + ':' + military_rank_detail[:rank_code]
    end

    # Sort operator. Default sort should be by id ascending
    #
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      id <=> other.id
    end
  end
end
