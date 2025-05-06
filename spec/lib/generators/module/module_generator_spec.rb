# frozen_string_literal: true

require 'rails_helper'
require 'generators/module/module_generator'

describe ModuleGenerator do
  let(:module_name) { 'foo' }

  after do
    # remove generated files
    FileUtils.rm_rf(Rails.root.glob("modules/#{module_name}"))
  end

  describe 'create_directory_structure' do
    let(:path) { Rails.root.join('modules', module_name, 'app') }
    let(:spec_path) { Rails.root.join('modules', module_name, 'spec') }

    it 'the directories should exist' do
      ModuleGenerator.new([module_name]).create_directory_structure
      %w[controllers models serializers services].each do |module_dir|
        expect(File.directory?("#{path}/#{module_dir}/#{module_name}")).to be(true)
      end
    end

    it 'the spec directories should exist' do
      ModuleGenerator.new([module_name]).create_directory_structure
      %w[controllers models lib serializers services factories support].each do |module_dir|
        expect(File.directory?("#{spec_path}/#{module_dir}/#{module_name}")).to be(true)
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
      create  modules/foo/.adr-dir
      create  modules/foo/.irbrc
      create  modules/foo/.rspec
      create  modules/foo/.gitignore
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

    it 'creates the adr-dir' do
      expect(File).to exist("#{path}/.adr-dir")
    end

    it 'creates the irbrc' do
      expect(File).to exist("#{path}/.irbrc")
    end

    it 'creates the rspec' do
      expect(File).to exist("#{path}/.rspec")
    end

    it 'creates the gitignore' do
      expect(File).to exist("#{path}/.gitignore")
    end
  end

  describe 'file insertion methods' do
    let(:module_name) { 'foo' }

    it 'inserts to the simplecov helper' do
      options = {
        insert_matcher: "add_group 'Foo', 'modules/foo/'",
        new_entry: "    add_group 'Foo', 'modules/foo/'\n",
        regex: /# Modules(.*)end/m
      }
      allow_any_instance_of(ModuleGenerator).to(
        receive(:module_generator_file_insert).with('spec/simplecov_helper.rb', options).and_return('stub insertion')
      )
      simplecov_updater = ModuleGenerator.new([module_name]).update_simplecov_helper
      expect(simplecov_updater).to eq('stub insertion')
    end

    it 'inserts to the spec helper' do
      options = {
        insert_matcher: "add_group 'Foo', 'modules/foo/'",
        new_entry: "    add_group 'Foo', 'modules/foo/'\n",
        regex: /# Modules(.*)# End Modules/m
      }

      allow_any_instance_of(ModuleGenerator).to(
        receive(:module_generator_file_insert).with('spec/spec_helper.rb', options).and_return('stub insertion')
      )
      spec_updater = ModuleGenerator.new([module_name]).update_spec_helper
      expect(spec_updater).to eq('stub insertion')
    end

    it 'inserts to the gemfile' do
      options = {
        insert_matcher: "gem '#{module_name}'",
        new_entry: "  gem '#{module_name}'\n"
      }

      allow_any_instance_of(ModuleGenerator).to(
        receive(:module_generator_file_insert).with('Gemfile', options).and_return('stub insertion')
      )
      gemfile_updater = ModuleGenerator.new([module_name]).update_gemfile
      expect(gemfile_updater).to eq('stub insertion')
    end

    it 'inserts to the routes file' do
      options = {
        insert_matcher: "mount Foo::Engine, at: '/foo'",
        new_entry: "  mount Foo::Engine, at: '/foo'\n",
        regex: /# Modules(.*)# End Modules/m
      }

      allow_any_instance_of(ModuleGenerator).to(
        receive(:module_generator_file_insert).with('config/routes.rb', options).and_return('stub insertion')
      )
      routes_updater = ModuleGenerator.new([module_name]).update_routes_file
      expect(routes_updater).to eq('stub insertion')
    end

    it 'bundle installs' do
      allow_any_instance_of(ModuleGenerator).to receive(:update_and_install).and_return('bundle installing...')
      installer = ModuleGenerator.new([module_name]).update_and_install
      expect(installer).to eq('bundle installing...')
    end
  end
end
