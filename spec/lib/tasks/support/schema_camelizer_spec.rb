# frozen_string_literal: true

require 'rails_helper'
require './lib/tasks/support/schema_camelizer.rb'

describe SchemaCamelizer do
  describe '#camel_schema' do
    it 'should camel-inflect keys'
    it 'should camel-inflect nested keys'
    it 'should camel-inflect nested keys'
  end

  describe '#referenced_schemas' do
    it 'should be empty with no references'
    it 'should be an Array of SchemaCamelizers for referenced schemas'
  end

  describe '#already_camelized' do
    it 'when the source schema has camel keys it should be true'
    it 'when the source schema has snake keys it should be false'
  end

  describe '#camel_path' do
    it 'should be in schemas_camelized directory'
  end

  describe '#unchanged_schemas' do
    it 'should be an array of names of schemas that are already_camelized'
    it 'should be empty if the original schema was snake case'
  end

  describe '#save!' do
    it 'should write a file to the disk'
    it 'should return an array of paths to saved files'
  end
end
