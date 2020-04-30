# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'json_schema_definition_name.rb')

describe AppealsApi::JsonSchemaDefinitionName do
  it 'capitalizes' do
    expect(described_class.new('thing').to_swagger).to eq 'Thing'
  end

  it 'prepends prefix' do
    expect(described_class.new('thing', prefix: 'Hello').to_swagger).to eq 'HelloThing'
  end

  it 'nil definition name OK' do
    expect(described_class.new(nil, prefix: 'Hello').to_swagger).to eq 'Hello'
  end

  it 'empty string definition name OK' do
    expect(described_class.new('', prefix: 'Hello').to_swagger).to eq 'Hello'
  end

  it 'nil prefix OK' do
    expect(described_class.new('thing', prefix: nil).to_swagger).to eq 'Thing'
  end

  it 'empty string prefix OK' do
    expect(described_class.new('thing', prefix: '').to_swagger).to eq 'Thing'
  end
end
