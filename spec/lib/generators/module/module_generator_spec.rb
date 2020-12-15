# frozen_string_literal: true

require 'rails_helper'
require 'generators/module/module_generator'

describe ModuleGenerator do
  after(:all) { FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')]) }

  describe 'create_directory_structure' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_directory_structure }

      let(:path) { Rails.root.join('modules', 'foo', 'app') }

      it 'the directories should exist' do
        %w[controllers models serializers service].each do |module_dir|
          File.directory?("#{path}/#{module_dir}").should be true
        end
      end
    end
  end

  describe 'create_engine' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_engine }

      let(:path) { Rails.root.join('modules', 'foo', 'lib') }

      it 'creates the engine file' do
        expect(File).to exist("#{path}/foo/engine.rb")
      end

      it 'creates the version file' do
        expect(File).to exist("#{path}/foo/version.rb")
      end

      it 'creates the module file' do
        expect(File).to exist("#{path}/foo.rb")
      end
    end
  end

  describe 'create_additional_files' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_additional_files }

      let(:path) { Rails.root.join('modules', 'foo') }

      it 'creates the rakefile' do
        expect(File).to exist("#{path}/Rakefile")
      end

      it 'creates the readme' do
        expect(File).to exist("#{path}/README.rdoc")
      end

      it 'creates the rails file' do
        expect(File).to exist("#{path}/bin/rails")
      end

      it 'creates the spec_helper' do
        expect(File).to exist("#{path}/spec/spec_helper.rb")
      end

      it 'creates the routes file' do
        expect(File).to exist("#{path}/config/routes.rb")
      end

      it 'creates the gemspec' do
        expect(File).to exist("#{path}/foo.gemspec")
      end

      it 'creates the Gemfile' do
        expect(File).to exist("#{path}/Gemfile")
      end
    end
  end
end
