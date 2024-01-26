# frozen_string_literal: true

module Vye
  class Vye::Verification < ApplicationRecord
    belongs_to :user_info
    belongs_to :award

    REQUIRED_ATTRIBUTES = %i[
      act_begin act_end award_id change_flag rpo_code rpo_flag source_ind
    ].freeze

    validates(*REQUIRED_ATTRIBUTES, presence: true)
  end
end
