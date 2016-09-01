# frozen_string_literal: true
module ValidationHelpers
  def expect_attr_valid(model, attr)
    model.valid?
    expect(model.errors[attr]).to eq([])
  end

  def expect_attr_invalid(model, attr, error = 'is invalid')
    model.valid?
    expect(model.errors[attr].include?(error)).to eq(true)
  end
end
