# frozen_string_literal: true

module Vye
  class VerificationSerializer
    def initialize(resource)
      @resource = resource
    end

    def to_json(*)
      Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
    end

    def serializable_hash
      {
        award_id: @resource&.award_id,
        act_begin: @resource&.act_begin,
        act_end: @resource&.act_end,
        transact_date: @resource&.transact_date,
        monthly_rate: @resource&.monthly_rate,
        number_hours: @resource&.number_hours,
        source_ind: @resource&.source_ind
      }
    end
  end
end
