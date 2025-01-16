# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators'
require_relative '../../../lib/generators/module_helper'

describe ModuleHelper do
  class DummyGenerator < Rails::Generators::NamedBase
    include ModuleHelper
  end

  context 'file insert' do
    it 'tests module_generator_file_insert method' do
      options_hash = {}
      options_hash[:insert_matcher] = "gem 'foo'"
      options_hash[:new_entry] = "\t#{options_hash[:insert_matcher]}\n"

      dummy_generator = DummyGenerator.new(['module_name'])
      allow_any_instance_of(DummyGenerator).to receive(:insert_into_file).and_return('stub insert')
      gemfile_updater = dummy_generator.module_generator_file_insert('Gemfile', options_hash)
      expect(gemfile_updater).to be(true)
    end
  end
end
