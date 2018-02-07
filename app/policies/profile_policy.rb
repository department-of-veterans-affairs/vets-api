# frozen_string_literal: true

ProfilePolicy = Struct.new(:user, :profile) do
  def profile?
    user.loa1? || user.loa2? || user.loa3?
  end

  def partial_forms?
    true
  end

  def prefill_data?
    true
  end
end
