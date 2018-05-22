# frozen_string_literal: true

Vet360Policy = Struct.new(:user, :vet360) do
  def access?
    user.vet360_id.present?
  end
end
