VyePolicy = Struct.new(:user, :user_info) do
  def access?
    return true if user.present?

    false
  end
end
