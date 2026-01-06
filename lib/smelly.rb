module Smelly
  def duplicate_method_calls(user)
    user.send_email
    user.send_email
    user.send_email
  end
end
