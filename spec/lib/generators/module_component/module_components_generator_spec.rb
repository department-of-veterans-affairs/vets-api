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

    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'controllers') }

    context 'with component_name' do
      it 'creates a module controller file with different name from module' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'controller', 'component_name' => 'bar' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/bar_controller.rb")
      end
    end

    context 'without component_name' do
      it 'creates a module controller file with same name as module' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'controller' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/foo_controller.rb")
      end
    end
  end

  describe 'creates a serializer' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'serializers') }

    context 'with component_name' do
      it 'creates a module serializer file with different name from module' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'serializer', 'component_name' => 'bar' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/bar_serializer.rb")
      end
    end

    context 'without component_name' do
      it 'creates a module serializer file with same name as module' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'serializer' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/foo_serializer.rb")
      end
    end
  end

  describe 'creates a model' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'models') }

    context 'with component_name' do
      it 'creates a module model file with different name from module' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'model', 'component_name' => 'bar' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/bar.rb")
      end
    end

    context 'without component_name' do
      it 'creates a module model file with same name as module' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'model' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/foo.rb")
      end
    end
  end

  describe 'creates a service and configuration' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    # this prevents a prompt about overwriting configuration.rb if tests are run out of order
    before do
      FileUtils.rm_f(Rails.root.glob('modules/foo/app/services/foo/v0/configuration.rb'))
    end

    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'services') }

    context 'with component_name' do
      it 'creates a module service file with different name from module and a configuration file' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'service', 'component_name' => 'bar' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/bar_service.rb")
        expect(File).to exist("#{path}/foo/v0/configuration.rb")
      end
    end

    context 'without component_name' do
      it 'creates a module service file with same name as module and a configuration file' do
        module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'service' }])
        module_gen.create_component
        expect(File).to exist("#{path}/foo/v0/foo_service.rb")
        expect(File).to exist("#{path}/foo/v0/configuration.rb")
      end
    end
  end

  describe 'does not create an invalid component' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'bad_components') }

    it 'does not create the bad_component' do
      module_gen = ModuleComponentGenerator.new(['foo', { 'method' => 'bad_component' }])
      module_gen.create_component
      expect(File).not_to exist("#{path}/foo/v0/foo_bad_component.rb")
    end
  end

  describe 'test message to stdout for an invalid component' do
    before(:all) do
      ModuleGenerator.new(['foo']).create_directory_structure
    end

    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo', 'app', 'bad_components') }

    it 'does not create the bad_component' do
      expected_stdout = "\nbad_component is not a known generator command.Commands allowed " \
                        "are controller, model, serializer and service\n"
      expect do
        ModuleComponentGenerator.new(['foo', { 'method' => 'bad_component' }]).create_component
      end.to output(expected_stdout).to_stdout
      expect(File).not_to exist("#{path}/foo/v0/foo_bad_component.rb")
    end
  end

  describe 'it creates the module structure if user selects yes' do
    after(:all) { FileUtils.rm_rf(Rails.root.glob('modules/foo')) }

    let(:path) { Rails.root.join('modules', 'foo') }

    it 'creates the module controller file' do
      # stub backtick to create a new module
      allow_any_instance_of(ModuleComponentGenerator).to receive(:`).and_return('stub module creation')
      allow_any_instance_of(ModuleComponentGenerator).to receive(:yes?).and_return(true)
      module_component_generator = ModuleComponentGenerator.new(['foo', { 'method' => 'controller' }])
      module_component_generator.prompt_user
      module_component_generator.create_component
      expect(Dir).to exist(path.to_s)
      expect(File).to exist("#{path}/app/controllers/foo/v0/foo_controller.rb")
    end
  end
end
