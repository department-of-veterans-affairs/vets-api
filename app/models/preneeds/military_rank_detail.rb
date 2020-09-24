# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models military rank detail from the EOAS service.
  # Attribute of a {Preneeds::MilitaryRank} object.
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute branch_of_service_code
  #   @return [String] branch of service abbreviated code
  # @!attribute rank_code
  #   @return [String] rank abbreviated code
  # @!attribute rank_descr
  #   @return [String] rank description
  #
  class MilitaryRankDetail < Common::Base
    attribute :branch_of_service_code, String
    attribute :rank_code, String
    attribute :rank_descr, String

    # return [String] #branch_of_service code and #rank_code joined with ':'
    #
    def id
      branch_of_service_code + ':' + rank_code
    end
  end
end
