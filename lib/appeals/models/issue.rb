# frozen_string_literal: true

module Appeals
  module Models
    class Issue
      include Virtus.model(nullify_blank: true)

      attribute :active, Boolean
      attribute :date, Date
      attribute :description,	String
      attribute :diagnostic_code,	String
      attribute :last_action, String
    end
  end
end
