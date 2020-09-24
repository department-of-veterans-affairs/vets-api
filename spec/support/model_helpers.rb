# frozen_string_literal: true

module ModelHelpers
  def model_exists?(model)
    model.class.exists?(model.id)
  end
end
