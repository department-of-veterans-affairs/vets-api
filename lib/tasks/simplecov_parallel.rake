# frozen_string_literal: true

require 'common/exceptions/base_error'

if Rails.env.test?
  require_relative '../../spec/simplecov_helper'
  namespace :simplecov do
    desc 'merge_results'
    task report_coverage: :environment do
      SimpleCovHelper.report_coverage
    end
  end
end
