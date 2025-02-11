# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

module Faker
  class Form < Base
    class << self
      def id
        prefix = Faker::Number.number(digits: 4)
        suffix = Faker::Alphanumeric.alpha(number: 2).upcase
        "#{prefix}#{suffix}"
      end
    end
  end
end

module VcrHelpers
  VCR_OPTIONS = {
    match_requests_on: %i[
      method uri headers
    ].freeze
  }.freeze

  def use_cassette(name, options = {}, &)
    options.with_defaults!(
      **VCR_OPTIONS,
      use_spec_name_prefix: true
    )

    options.delete(:use_spec_name_prefix) and
      name = spec_name_prefix / name

    VCR.use_cassette(name, options, &)
  end

  def spec_name_prefix
    caller.each do |call|
      call = call.split(':').first
      next unless call.end_with?('_spec.rb')

      call.delete_prefix!((AccreditedRepresentativePortal::Engine.root / 'spec/').to_s)
      call.delete_suffix!('.rb')
      return Pathname('accredited_representative_portal') / call
    end
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_run :focus

  config.include VcrHelpers
end
