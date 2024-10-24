# frozen_string_literal: true

module VANotify::OtherTeam
  class OtherForm
    def self.call(_notification)
      true
    end
  end
end

module VANotify::NonCompliantModule
  class NonCompliantClass
    def self.not_call(_notification)
      false
    end
  end
end
