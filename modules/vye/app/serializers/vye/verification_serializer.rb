# frozen_string_literal: true

module Vye
  class VerificationSerializer < ActiveModel::Serializer
    attributes(
      :award_id,
      :act_begin, :act_end,
      :transact_date,
      :monthly_rate, :number_hours, :source_ind
    )
  end
end
