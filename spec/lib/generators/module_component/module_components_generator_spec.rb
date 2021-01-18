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

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'bad_components') }

    it 'does not create the bad_component' do
      expect(File).not_to exist("#{path}/foo/v0/foo_bad_component.rb")
    end
  end

  describe 'does not create an invalid component but does create a valid one' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
      ModuleComponentGenerator.new(%w[foo controller bad_component]).create_component
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app') }

    it 'does not create the bad_component' do
      expect(File).not_to exist("#{path}/bad_components/foo/v0/foo_bad_component.rb")
      expect(File).to exist("#{path}/controllers/foo/v0/foo_controller.rb")
    end
  end

  describe 'it creates the module structure if user selects yes' do
    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo') }

    it 'creates the module controller and serializer files' do
      # stub backtick to create a new module
      allow_any_instance_of(ModuleComponentGenerator).to receive(:`).and_return('stub module creation')
      allow_any_instance_of(ModuleComponentGenerator).to receive(:yes?).and_return(true)
      ModuleComponentGenerator.new(%w[foo controller serializer]).create_component
      expect(Dir).to exist(path.to_s)
      expect(File).to exist("#{path}/app/serializers/foo/v0/foo_serializer.rb")
    end
  end

  describe 'it calls the create_commit_message method' do
    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo') }

    it 'creates the module controller and serializer files' do
      allow_any_instance_of(
        ModuleComponentGenerator
      ).to receive(:create_commit_message).and_return('stub commit method')
      module_component_generator = ModuleComponentGenerator.new(%w[foo controller])
      expect(module_component_generator.create_commit_message).to eq('stub commit method')
    end
  end

  describe 'it calls the create_commit_message method with non nil commit_message_methods' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo') }

    it 'creates the module controller and serializer files' do
      allow_any_instance_of(
        ModuleComponentGenerator
      ).to receive(:create_commit_message).and_return('stub commit method')

      module_component_generator = ModuleComponentGenerator.new(%w[foo controller])
      module_component_generator.create_component

      expect(module_component_generator.commit_message_methods).not_to be_nil
      expect(module_component_generator.create_commit_message).to eq('stub commit method')
    end
  end

  describe 'it calls the create_commit_message method with nil commit_message_methods' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo') }

    it 'creates the module controller and serializer files' do
      allow_any_instance_of(
        ModuleComponentGenerator
      ).to receive(:create_commit_message).and_return('stub commit method')

      module_component_generator = ModuleComponentGenerator.new(%w[foo bad_component])
      module_component_generator.create_component

      expect(module_component_generator.commit_message_methods).to eq([])
      expect(module_component_generator.create_commit_message).to eq('stub commit method')
    end
  end


end
