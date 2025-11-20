# frozen_string_literal: true

require 'rails_helper'
require 'identity/model/inspect'

class TestInspect
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Identity::Model::Inspect

  attribute :attr1, :string
  attribute :attr2, :integer
  attribute :attr3, :boolean
  attribute :attr4, :float
end

RSpec.describe Identity::Model::Inspect do
  let(:model) { TestInspect.new(attr1: 'value1', attr2: 42, attr3: true, attr4: 3.14) }
  let(:expected_inspect_output) do
    '#<TestInspect attr1: "value1", attr2: 42, attr3: true, attr4: 3.14>'
  end

  let(:expected_pretty_print_output) do
    /\A#<TestInspect:0x[0-9a-f]+\n\s*attr1: "value1",\n\s*attr2: 42,\n\s*attr3: true,\n\s*attr4: 3\.14>\n\z/
  end

  describe '#inspect' do
    it 'returns a formatted string representation of the model' do
      expect(model.inspect).to eq(expected_inspect_output)
    end
  end

  describe '#pretty_print' do
    it 'returns a formatted string representation of the model' do
      output = StringIO.new
      PP.pp(model, output)
      expect(output.string).to match(expected_pretty_print_output)
    end
  end
end
