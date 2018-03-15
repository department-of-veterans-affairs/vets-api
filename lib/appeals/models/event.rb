# frozen_string_literal: true

module Appeals
  module Models
    class Event < Common::Base
      attribute :type, String
      attribute :date, Date
      attribute :details, Hash
    end
  end
end
