# frozen_string_literal: true

module ValidationHelpers
  extend ActiveSupport::Concern

  def expect_attr_valid(model, attr)
    model.valid?
    expect(model.errors[attr]).to eq([])
  end

  class_methods do
    def validate_inclusion(attr, array)
      array = Array.wrap(array)

      it "#{attr} should have the right value" do
        model = described_class.new
        array.each do |array_item|
          model[attr] = array_item
          expect_attr_valid(model, attr)
        end

        model[attr] = "#{array[0]}foo"
        expect_attr_invalid(model, attr, 'is not included in the list')
      end
    end
  end

  def expect_attr_invalid(model, attr, error = 'is invalid')
    model.valid?
    expect(model.errors[attr].include?(error)).to be(true)
  end
end
