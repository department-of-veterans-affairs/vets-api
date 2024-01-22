# frozen_string_literal: true

module Vye
  class Vye::Award < ApplicationRecord
    belongs_to :user_info

    REQUIRED_ATTRIBUTES = %i[
      award_begin_date award_end_date begin_rsn cur_award_ind end_rsn
      monthly_rate number_hours payment_date training_time type_hours type_training
    ].freeze

    validates(*REQUIRED_ATTRIBUTES, presence: true)
  end
end
