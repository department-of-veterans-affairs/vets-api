# frozen_string_literal: true

module Appeals
  module Models
    class Evidence
      include Virtus.model(nullify_blank: true)

      attribute :description, String
      attribute :date, Date
    end
  end
end
