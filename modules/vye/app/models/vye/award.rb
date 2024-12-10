# frozen_string_literal: true

module Vye
  class Vye::Award < ApplicationRecord
    belongs_to :user_info
    has_one :verification, dependent: :nullify

    enum :cur_award_ind, %i[current future past],
         prefix: :award_ind,
         mapping: { current: 'C', future: 'F', past: 'P' }

    validates(
      *%i[
        cur_award_ind
        monthly_rate training_time
      ].freeze,
      presence: true
    )
  end
end
