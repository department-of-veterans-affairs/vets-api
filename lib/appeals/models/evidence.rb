# frozen_string_literal: true

module Appeals
  module Models
    class Evidence < Common::Base
      attribute :description, String
      attribute :date, Date
    end
  end
end
