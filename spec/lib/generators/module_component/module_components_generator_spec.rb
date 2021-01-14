# frozen_string_literal: true

require 'rails_helper'
require 'generators/module_component/module_component_generator'
require 'generators/module/module_generator'

RSpec.describe 'ModuleComponent', type: :generator do
  before(:all) do
    @original_stdout = $stdout
    # Redirect stdout to suppress generator output
    $stdout = File.open(File::NULL, 'w')
  end

  after(:all) do
    $stdout = @original_stdout
  end

  describe 'creates a controller' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo controller]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'controllers') }

    it 'creates the module controller file' do
      expect(File).to exist("#{path}/foo/v0/foo_controller.rb")
    end
  end

  describe 'creates a serializer' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo serializer]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'serializers') }

    it 'creates the module serializer file' do
      expect(File).to exist("#{path}/foo/v0/foo_serializer.rb")
    end
  end

  describe 'creates a model' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo model]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'models') }

    it 'creates the module model file' do
      expect(File).to exist("#{path}/foo/v0/foo_model.rb")
    end
  end

  describe 'creates a service and configuration' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo service]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'services') }

    it 'creates the module service and configuration files' do
      expect(File).to exist("#{path}/foo/v0/foo_service.rb")
      expect(File).to exist("#{path}/foo/v0/configuration.rb")
    end
  end

  describe 'creates multiple components' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo controller serializer]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app') }

    it 'creates the module controller and serializer files' do
      expect(File).to exist("#{path}/controllers/foo/v0/foo_controller.rb")
      expect(File).to exist("#{path}/serializers/foo/v0/foo_serializer.rb")
    end
  end

  describe 'does not create an invalid component' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo bad_component]).create_component
    end

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'bad_components') }

    it 'does not create the bad_component' do
      expect(File).not_to exist("#{path}/foo/v0/foo_bad_component.rb")
    end
  end

  describe 'it creates the module structure if user selects yes' do
    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo') }

    it 'creates the module controller files' do
      allow_any_instance_of(ModuleComponentGenerator).to receive(:yes?).and_return(true)
      ModuleComponentGenerator.new(%w[foo controller]).prompt_user
      expect(Dir).to exist(path.to_s)
    end
  end
end
