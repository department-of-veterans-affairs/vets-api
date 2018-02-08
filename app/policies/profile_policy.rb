# frozen_string_literal: true

ProfilePolicy = Struct.new(:user, :profile) do
  def read?
    user.loa1? || user.loa2? || user.loa3?
  end

  def identity_proofed?
    user.loa3?
  end

  def list_prefills?
    user.identity.present?
  end
end
