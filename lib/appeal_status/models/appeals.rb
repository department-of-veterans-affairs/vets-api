# frozen_string_literal: true
module AppealStatus
  module Models
    class Appeal
      include Virtus.model
      attribute :appeal_status, String
    end

    class Appeals
      include Virtus.model
      attribute :appeals, Array[Appeal]
    end
  end
end
