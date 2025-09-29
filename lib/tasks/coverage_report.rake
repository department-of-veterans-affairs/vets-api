# frozen_string_literal: true

namespace :coverage do
  desc 'Collates SimpleCov resultsets from all shards'
  task report: :environment do
    require 'simplecov'

    SimpleCov.collate Dir['simplecov-resultset-*/.resultset.json'], 'rails' do
      # Pick formatters for final output
      formatter SimpleCov::Formatter::MultiFormatter.new([
                                                           SimpleCov::Formatter::SimpleFormatter,
                                                           SimpleCov::Formatter::HTMLFormatter
                                                         ])
      coverage_dir 'coverage'
    end
  end
end
