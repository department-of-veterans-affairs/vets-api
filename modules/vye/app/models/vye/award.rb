# frozen_string_literal: true

module Vye
  class Vye::Award < ApplicationRecord
    belongs_to :user_info

    enum cur_award_ind: { current: 'C', future: 'F', past: 'P' }

    validates(
      *%i[
        award_end_date cur_award_ind end_rsn
        monthly_rate number_hours payment_date training_time
      ].freeze,
      presence: true
    )
  end
end
