# frozen_string_literal: true

module Appeals
  module Models
    class Alert < Common::Base
      attribute :type, String
      attribute :details,	Hash
    end
  end
end
