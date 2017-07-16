module ModelHelpers
  def model_exists?(model)
    model.class.exists?(model.id)
  end
end
