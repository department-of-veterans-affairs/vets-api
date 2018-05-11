# frozen_string_literal: true

guard :rspec, cmd: 'DISABLE_SPRING=y NOCOVERAGE=y bin/rspec' do
  require 'guard/rspec/dsl'
  dsl = Guard::RSpec::Dsl.new(self)

  watch(dsl.rspec.spec_helper) { dsl.rspec.spec_dir }
  watch(dsl.rspec.spec_support) { dsl.rspec.spec_dir }
  watch(dsl.rspec.spec_files)

  dsl.watch_spec_files_for(dsl.ruby.lib_files)
  dsl.watch_spec_files_for(dsl.rails.app_files)

  watch(dsl.rails.controllers) do |m|
    [dsl.rspec.spec.call("routing/#{m[1]}_routing"),
     dsl.rspec.spec.call("controllers/#{m[1]}_controller")]
  end

  watch(dsl.rails.spec_helper) { rspec.spec_dir }
  watch(dsl.rails.routes) { "#{rspec.spec_dir}/routing" }
  watch(dsl.rails.app_controller) { "#{rspec.spec_dir}/controllers" }
end

guard :rubocop, cli: %w[--auto-correct] do
  watch(/.+\.rb$/)
  watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end
