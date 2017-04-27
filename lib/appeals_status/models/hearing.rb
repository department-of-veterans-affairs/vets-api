# frozen_string_literal: true
module AppealStatus
  module Models
    class Hearing
      include Virtus.model

      attribute :requested, Boolean
      attribute :scheduled, Boolean
      attribute :date, Date
    end
  end
end
