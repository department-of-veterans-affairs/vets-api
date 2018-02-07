# frozen_string_literal: true

class Authorization
  attr_writer :user

  def initialize(user)
    @user = user
  end

  def authorized?(policy, method)
    Pundit.policy!(@user, policy).send(method)
  end

  def service_list
    
  end
end
