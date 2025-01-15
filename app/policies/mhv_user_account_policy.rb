# frozen_string_literal: true

class MHVUserAccountPolicy
  attr_reader :user

  def initialize(user, _record)
    @user = user
  end

  def show?
    user.present? && user.can_create_mhv_account?
  end
end
