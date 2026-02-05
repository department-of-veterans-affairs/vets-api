# frozen_string_literal: true

module Console1984
  class << self
    def running_protected_environment?
      Rails.env.development?
    end
  end
end
