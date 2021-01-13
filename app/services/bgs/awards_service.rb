# frozen_string_literal: true

module BGS
  ##
  # Allows retrieval of composite monetary award amounts that veterans are entitled
  #
  class AwardsService < BaseService
    ##
    # Gets composite monetary awards that veterans are entitled along with relevant metadata
    #
    # @return [Hash]
    #
    def get_awards
      @service.awards.find_award_by_participant_id(@user.participant_id, @user.ssn) ||
        @service.awards.find_award_by_ssn(@user.ssn)
    rescue => e
      report_error(e)
    end

    ##
    # Returns gross amount of composite monetary awards veteran is entitled to
    #
    # @return [String]
    #
    def gross_amount
      get_awards[:gross_amt]
    end
  end
end
