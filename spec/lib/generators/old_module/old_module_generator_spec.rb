# frozen_string_literal: true

require 'rails_helper'
require 'generators/module/module_generator'

describe ModuleGenerator do
  describe 'create_app' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_app }

      after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

      let(:path) { Rails.root.join('modules', 'foo') }

      it 'creates the app controller' do
        expect(File).to exist("#{path}/app/controllers/foo/application_controller.rb")
      end

      it 'creates the endpoint controller' do
        expect(File).to exist("#{path}/app/controllers/foo/v0/foo_controller.rb")
      end

      it 'creates the model' do
        expect(File).to exist("#{path}/app/models/foo/resource.rb")
      end

      it 'creates the serializer' do
        expect(File).to exist("#{path}/app/serializers/foo/foo_serializer.rb")
      end

      it 'creates the service configurations' do
        expect(File).to exist("#{path}/app/services/foo/configuration.rb")
      end

      it 'creates the service' do
        expect(File).to exist("#{path}/app/services/foo/service.rb")
      end
    end
  end

  describe 'create_lib' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_lib }

      after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

      let(:path) { Rails.root.join('modules', 'foo', 'lib') }

      it 'creates the engine file' do
        expect(File).to exist("#{path}/foo/engine.rb")
      end

      it 'creates the version file' do
        expect(File).to exist("#{path}/foo/version.rb")
      end

      it 'creates the rake tasks' do
        expect(File).to exist("#{path}/tasks/foo_tasks.rake")
      end

      it 'creates the module file' do
        expect(File).to exist("#{path}/foo.rb")
      end
    end
  end

  describe 'create_config' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_config }

      after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

      let(:path) { Rails.root.join('modules', 'foo') }

      it 'creates the rails file' do
        expect(File).to exist("#{path}/bin/rails")
      end

      it 'creates the routes file' do
        expect(File).to exist("#{path}/config/routes.rb")
      end

      it 'creates the gemspec' do
        expect(File).to exist("#{path}/foo.gemspec")
      end

      it 'creates the rakefile' do
        expect(File).to exist("#{path}/Rakefile")
      end

      it 'creates the Gemfile' do
        expect(File).to exist("#{path}/Gemfile")
      end
    end
  end
end
