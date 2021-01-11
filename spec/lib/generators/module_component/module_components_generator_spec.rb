# frozen_string_literal: true

require 'rails_helper'
require 'generators/module_component/module_component_generator'
require 'generators/module/module_generator'

RSpec.describe 'ModuleComponent', type: :generator do
  describe 'creates a controller' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo controller]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'controllers') }

    it 'creates the module controller file' do
      File.exist?("#{path}/foo/v0/foo_controller.rb").should be true
    end
  end


  describe 'creates multiple components components' do
  end


  describe 'does not create an invalid component' do
  end

  describe 'it creates the module structure if user selects yes' do
  end

end
