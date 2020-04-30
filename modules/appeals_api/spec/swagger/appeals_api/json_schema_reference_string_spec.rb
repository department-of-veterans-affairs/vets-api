# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'json_schema_reference_string.rb')

describe AppealsApi::JsonSchemaReferenceString do
  it 'capitalizes' do
    expect(described_class.new('#/definitions/thing').to_swagger).to eq '#/components/schemas/Thing'
  end

  it 'prepends prefix' do
    expect(described_class.new('#/definitions/thing', prefix: 'Hello').to_swagger).to eq(
      '#/components/schemas/HelloThing'
    )
  end

  it 'nil reference string throws an ArgumentError' do
    expect { described_class.new(nil) }.to raise_error ArgumentError
  end

  it 'empty reference string throws an ArgumentError' do
    expect { described_class.new('') }.to raise_error ArgumentError
  end

  it 'malformed reference string throws an ArgumentError' do
    expect { described_class.new('#/definitions/something/else') }.to raise_error ArgumentError
  end

  it 'reference string without definition name is OK' do
    expect(described_class.new('#/definitions').to_swagger).to eq '#/components/schemas/'
  end

  it 'reference string without definition name is OK (trailing slash)' do
    expect(described_class.new('#/definitions/').to_swagger).to eq '#/components/schemas/'
  end

  it 'reference string without definition name + prefix is OK' do
    expect(described_class.new('#/definitions/', prefix: 'Hello').to_swagger).to eq '#/components/schemas/Hello'
  end

  it 'nil prefix OK' do
    expect(described_class.new('#/definitions/thing', prefix: nil).to_swagger).to eq(
      '#/components/schemas/Thing'
    )
  end

  it 'empty string prefix OK' do
    expect(described_class.new('#/definitions/thing', prefix: '').to_swagger).to eq(
      '#/components/schemas/Thing'
    )
  end
end
