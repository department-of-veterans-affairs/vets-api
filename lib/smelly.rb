# frozen_string_literal: true

class Smelly
  # Should trigger a DuplicateMethodCall code smell
  def dup_meth_calls(user)
    user.profile.name
    user.profile.name
    user.profile.name
    user.profile.name
    user.profile.name
    user.profile.name
  end
end
