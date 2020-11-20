# frozen_string_literal: true

module BGS
  class AwardsService < BaseService
    def get_awards
      @service.awards.find_award_by_participant_id(@user.participant_id)
    rescue => e
      report_error(e)
    end

    def gross_amount
      get_awards[:gross_amt]
    end
  end
end
