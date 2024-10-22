# frozen_string_literal: true

module OtherTeam
  class OtherForm
    def self.call(_notification)
      true
    end
  end
end

module NonCompliantModule
  class NonCompliantClass
    def self.not_call(_notification)
      false
    end
  end
end
