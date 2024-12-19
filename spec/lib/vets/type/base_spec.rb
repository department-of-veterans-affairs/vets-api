require 'rails_helper'

RSpec.describe Vets::Type::Base do
  let(:name) { 'example_name' }
  let(:klass) { String }
  let(:base_instance) { described_class.new(name, klass) }

  describe '#initialize' do
    it 'initializes with a name and a klass' do
      expect(base_instance.instance_variable_get(:@name)).to eq(name)
      expect(base_instance.instance_variable_get(:@klass)).to eq(klass)
    end
  end

  describe '#cast' do
    it 'raises NotImplementedError when called' do
      expect { base_instance.cast('value') }.to raise_error(NotImplementedError, "#{described_class} must implement #cast")
    end
  end
end
