# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module Letters
    class BenefitInformation < Common::Base
      attribute :monthly_award_amount, Float
      attribute :service_connected_percentage, Integer
      attribute :award_effective_date, DateTime
      attribute :has_chapter35_eligibility, Boolean
    end
  end
end
