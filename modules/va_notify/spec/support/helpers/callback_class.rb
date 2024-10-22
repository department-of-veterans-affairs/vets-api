# frozen_string_literal: true

module OtherTeam
  class OtherForm
    def self.call(notification)
      true
    end
  end
end

module NonCompliantModule
  class NonCompliantClass
    def self.not_call(notification)
      false
    end
  end
end
