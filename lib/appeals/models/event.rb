# frozen_string_literal: true

module Appeals
  module Models
    class Event
      include Virtus.model(nullify_blank: true)

      attribute :type, String
      attribute :date, Date
      attribute :details, Hash
    end
  end
end
