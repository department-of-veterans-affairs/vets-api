# frozen_string_literal: true

module Appeals
  module Models
    class Alert
      include Virtus.model(nullify_blank: true)

      attribute :type, String
      attribute :details,	Hash
    end
  end
end
