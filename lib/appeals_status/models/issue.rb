# frozen_string_literal: true
module AppealStatus
  module Models
    class Issue
      include Virtus.model

      attribute :program_area, String
      attribute :type, String
      attribute :rating_requested, String
      attribute :decision, String
    end
  end
end
