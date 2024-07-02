# frozen_string_literal: true

module Vye
  class Vye::Award < ApplicationRecord
    belongs_to :user_info
    has_many :verifications, dependent: :nullify

    enum(
      cur_award_ind: { current: 'C', future: 'F', past: 'P' },
      _prefix: :award_ind
    )

    validates(
      *%i[
        award_end_date cur_award_ind
        monthly_rate number_hours training_time
      ].freeze,
      presence: true
    )
  end
end
