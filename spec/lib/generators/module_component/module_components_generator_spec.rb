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
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'controllers') }

    it 'creates the module controller file' do
      module_generator = ModuleComponentGenerator.new(%w[foo controller])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq(['controller'])
      expect(File).to exist("#{path}/foo/v0/foo_controller.rb")
    end
  end

  describe 'creates a serializer' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'serializers') }

    it 'creates the module serializer file' do
      module_generator = ModuleComponentGenerator.new(%w[foo serializer])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq(['serializer'])
      expect(File).to exist("#{path}/foo/v0/foo_serializer.rb")
    end
  end

  describe 'creates a model' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'models') }

    it 'creates the module model file' do
      module_generator = ModuleComponentGenerator.new(%w[foo model])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq(['model'])
      expect(File).to exist("#{path}/foo/v0/foo.rb")
    end
  end

  describe 'creates a service and configuration' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'services') }

    it 'creates the module service and configuration files' do
      module_generator = ModuleComponentGenerator.new(%w[foo service])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq(['service'])
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
      module_generator = ModuleComponentGenerator.new(%w[foo controller serializer])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq(%w[controller serializer])
      expect(File).to exist("#{path}/controllers/foo/v0/foo_controller.rb")
      expect(File).to exist("#{path}/serializers/foo/v0/foo_serializer.rb")
    end
  end

  describe 'does not create an invalid component' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'bad_components') }

    it 'does not create the bad_component' do
      module_generator = ModuleComponentGenerator.new(%w[foo bad_component])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq([])
      expect(File).not_to exist("#{path}/foo/v0/foo_bad_component.rb")
    end
  end

  describe 'test message to stdout for an invalid component' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'bad_components') }

    it 'does not create the bad_component' do
      expected_stdout = "\nbad_component is not a known generator command.Commands allowed " \
        "are controller, model, serializer and service\n"
      expect do
        ModuleComponentGenerator.new(%w[foo bad_component]).create_component
      end.to output(expected_stdout).to_stdout
      expect(File).not_to exist("#{path}/foo/v0/foo_bad_component.rb")
    end
  end

  describe 'does not create an invalid component but does create a valid one' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

    let(:path) { Rails.root.join('modules', 'foo', 'app') }

    it 'does not create the bad_component' do
      module_generator = ModuleComponentGenerator.new(%w[foo controller bad_component])
      module_generator.create_component
      expect(module_generator.commit_message_methods).to eq(['controller'])
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
      module_component_generator = ModuleComponentGenerator.new(%w[foo controller serializer])
      module_component_generator.prompt_user
      module_component_generator.create_component
      expect(Dir).to exist(path.to_s)
      expect(File).to exist("#{path}/app/serializers/foo/v0/foo_serializer.rb")
    end
  end
end
