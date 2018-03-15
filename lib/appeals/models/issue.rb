# frozen_string_literal: true

module Appeals
  module Models
    class Issue < Common::Base
      attribute :active, Boolean
      attribute :date, Date
      attribute :description,	String
      attribute :diagnostic_code,	String
      attribute :last_action, String
    end
  end
end
