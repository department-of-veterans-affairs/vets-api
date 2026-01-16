# frozen_string_literal: true

module Console1984
  class << self
    def running_protected_environment?
      Rails.env.development? || Settings.vsp_environment == 'development' || Settings.vsp_environment == 'staging'
    end
  end
end
