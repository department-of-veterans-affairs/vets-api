# frozen_string_literal: true

class HCA::UserAttributes < MVI::Models::MviUserAttributes
  def gender
    # MVI message_user_attributes expects a gender value but it's not asked on the HCA form
    nil
  end

  def to_h
    super&.except(:gender)
  end
end
