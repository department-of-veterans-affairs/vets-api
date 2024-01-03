# frozen_string_literal: true

# Methods that normally exist on the Session class but not on 
# the ActionController::TestSession class, for use in testing

module TestSessionExtension
  def uuid
    self[:uuid]
  end

  def expire(_ttl)
    nil
  end

  def ttl_in_time
    Time.current.utc
  end
end
