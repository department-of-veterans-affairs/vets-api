# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'json_schema_reference_string.rb')

describe AppealsApi::JsonSchemaReferenceString do
  describe '#to_swagger' do
    it 'converts to a swagger-style reference' do
      expect(described_class.new('#/definitions/thing').to_swagger).to eq '#/components/schemas/thing'
    end

    it 'no definition name is OK' do
      expect(described_class.new('#/definitions').to_swagger).to eq '#/components/schemas'
    end

    it 'no definition name is OK (trailing slash)' do
      expect(described_class.new('#/definitions/').to_swagger).to eq '#/components/schemas/'
    end

    it 'malformed reference string throws exception' do
      expect { described_class.new('#/definitions/something/else').to_swagger }.to raise_error ArgumentError
    end
  end

  describe '#valid?' do
    it 'true' do
      expect(described_class.new('#/definitions/thing').valid?).to be true
    end

    it 'false (nil)' do
      expect(described_class.new(nil).valid?).to be false
    end

    it 'false (\'\')' do
      expect(described_class.new('').valid?).to be false
    end

    it 'false (malformed reference string)' do
      expect(described_class.new('#/definitions/something/else').valid?).to be false
    end
  end
end
