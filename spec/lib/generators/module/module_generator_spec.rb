# frozen_string_literal: true

require 'rails_helper'
require 'generators/module/module_generator'

describe ModuleGenerator do
  before(:all) do
    @original_stdout = $stdout
    # Redirect stdout to suppress generator output
    $stdout = File.open(File::NULL, 'w')
  end

  after(:all) do
    # restore stdout
    $stdout = @original_stdout
    # remove generated files
    FileUtils.rm_rf(Dir[Rails.root.join('modules', 'foo')])
  end

  describe 'create_directory_structure' do
    context 'once generated' do
      before(:all) { ModuleGenerator.new(['foo']).create_directory_structure }

      let(:path) { Rails.root.join('modules', 'foo', 'app') }

      it 'the directories should exist' do
        %w[controllers models serializers service].each do |module_dir|
          expect(File.directory?("#{path}/#{module_dir}")).to be(true)
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
