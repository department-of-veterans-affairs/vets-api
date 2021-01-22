# frozen_string_literal: true

require 'rails_helper'
require 'generators/module/module_generator'

describe ModuleGenerator do
  let(:module_name) { 'foo' }

  after do
    # remove generated files
    FileUtils.rm_rf(Dir[Rails.root.join('modules', module_name)])
  end

  describe 'create_directory_structure' do
    let(:path) { Rails.root.join('modules', module_name, 'app') }

    it 'the directories should exist' do
      ModuleGenerator.new([module_name]).create_directory_structure
      %w[controllers models serializers service].each do |module_dir|
        expect(File.directory?("#{path}/#{module_dir}")).to be(true)
      end
    end
  end

  describe 'create_engine' do
    before do
      create_message = <<MESSAGES
      create  modules/foo/lib/foo/engine.rb
      create  modules/foo/lib/foo/version.rb
      create  modules/foo/lib/foo.rb
MESSAGES
      expect do
        ModuleGenerator.new([module_name]).create_engine
      end.to output(create_message).to_stdout
    end

    let(:path) { Rails.root.join('modules', module_name, 'lib') }

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

  describe 'create_additional_files' do
    before do
      create_message = <<MESSAGES
      create  modules/foo/Rakefile
      create  modules/foo/README.rdoc
      create  modules/foo/bin/rails
       chmod  modules/foo/bin/rails
      create  modules/foo/spec/spec_helper.rb
      create  modules/foo/config/routes.rb
      create  modules/foo/foo.gemspec
      create  modules/foo/Gemfile
MESSAGES
      expect do
        ModuleGenerator.new([module_name]).create_additional_files
      end.to output(create_message).to_stdout
    end

    let(:path) { Rails.root.join('modules', module_name) }

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
