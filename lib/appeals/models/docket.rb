# frozen_string_literal: true

module Appeals
  module Models
    class Docket
      include Virtus.model(nullify_blank: true)

      attribute :month,	Date
      attribute :docket_month, Date
      attribute :front, Boolean
      attribute :total, Integer
      attribute :ahead, Integer
      attribute :ready, Integer
      attribute :eta, Date
    end
  end
end
