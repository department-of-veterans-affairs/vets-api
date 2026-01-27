# frozen_string_literal: true

module Console1984
  class << self
    def running_protected_environment?
      %w[development staging].include?(Settings.vsp_environment)
    end
  end
end
