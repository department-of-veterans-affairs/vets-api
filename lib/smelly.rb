# frozen_string_literal: true

class Smelly
  # Should trigger a code smell
  def missing_safe_method! = Rails.logger.debug 'This method is smelly'
end
