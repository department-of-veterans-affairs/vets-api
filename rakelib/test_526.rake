# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require_relative 'support/disability_compensation_form/test_runner'

namespace :test_526 do
  desc 'test submit endpoint'
  task :submit, [:env, :user_token, :number_of_runs] do |_, args|
    test_runner = TestRunner.new(args[:env], args[:user_token])
    test_runner.create_itf unless test_runner.active_itf?
    args[:number_of_runs].to_i.times { test_runner.submit }
  end

  desc 'test ratedDisabilities endpoint'
  task :rated_disabilities, [:env, :user_token] do |_, args|
    test_runner = TestRunner.new(args[:env], args[:user_token])
    test_runner.rated_disabilities
  end
end
