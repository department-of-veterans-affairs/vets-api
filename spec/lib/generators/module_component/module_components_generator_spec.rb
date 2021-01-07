# frozen_string_literal: true

require 'rails_helper'
require 'generators/module_component/module_component_generator'
require 'generators/module/module_generator'

RSpec.describe "ModuleComponents", type: :generator do

  describe 'creates one component' do
    context 'once generated'
      before(:all) { ModuleGenerator.new(['foo']).create_app }
      before(:all) { system("rails g module_component foo controller") }
      after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

      let(:path) { Rails.root.join('modules', 'foo', 'app') }

      it 'it should create the module controller file' do
          File.exists?("#{path}/controllers/foo_controller.rb").should be true
      end
    end
  end


  describe 'creates multiple components components' do
  end


  describe 'does not create an invalid component' do
  end

  describe 'it creates the module structure if user selects yes' do
  end

end
