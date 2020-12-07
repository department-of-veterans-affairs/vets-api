# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

# spec/simplecov_helper.rb
require 'active_support/inflector'
require 'simplecov'

class SimpleCovHelper
  def self.report_coverage(base_dir: './coverage_results')
    SimpleCov.start 'rails' do
      skip_check_coverage = ENV.fetch('SKIP_COVERAGE_CHECK', 'false')

      track_files '**/{app,lib}/**/*.rb'

      add_filter 'app/controllers/concerns/accountable.rb'
      add_filter 'config/initializers/clamscan.rb'
      add_filter 'lib/config_helper.rb'
      add_filter 'lib/feature_flipper.rb'
      add_filter 'lib/gibft/configuration.rb'
      add_filter 'lib/ihub/appointments/response.rb'
      add_filter 'lib/salesforce/configuration.rb'
      add_filter 'lib/vet360/address_validation/configuration.rb'
      add_filter 'lib/search/response.rb'
      add_filter 'lib/vet360/exceptions/builder.rb'
      add_filter 'lib/vet360/response.rb'
      add_filter 'modules/claims_api/app/controllers/claims_api/v0/forms/disability_compensation_controller.rb'
      add_filter 'modules/claims_api/app/controllers/claims_api/v1/forms/disability_compensation_controller.rb'
      add_filter 'modules/claims_api/app/swagger/*'
      add_filter 'modules/claims_api/lib/claims_api/health_checker.rb'
      add_filter 'lib/bip_claims/configuration.rb'
      add_filter 'version.rb'

      add_group 'Policies', 'app/policies'
      add_group 'Serializers', 'app/serializers'
      add_group 'Services', 'app/services'
      add_group 'Swagger', 'app/swagger'
      add_group 'Uploaders', 'app/uploaders'
      add_group 'AppealsApi', 'modules/appeals_api/'
      add_group 'ClaimsApi', 'modules/claims_api/'
      add_group 'CovidVaccine', 'modules/covid_vaccine/'
      add_group 'OpenidAuth', 'modules/openid_auth/'
      add_group 'VBADocuments', 'modules/vba_documents/'
      add_group 'Veteran', 'modules/veteran/'
      add_group 'VeteranVerification', 'modules/veteran_verification/'
      add_group 'OpenidAuth', 'modules/openid_auth/'
      add_group 'VAOS', 'modules/vaos/'

      minimum_coverage(90) unless skip_check_coverage
      refuse_coverage_drop unless skip_check_coverage
      merge_timeout(3600)
    end
    new(base_dir: base_dir).merge_results
  end

  attr_reader :base_dir

  def initialize(base_dir:)
    @base_dir = base_dir
  end

  def all_results
    Dir["#{base_dir}/.resultset*.json"]
  end

  def merge_results
    results = all_results.map { |file| SimpleCov::Result.from_hash(JSON.parse(File.read(file))) }
    SimpleCov::ResultMerger.merge_results(*results).tap do |result|
      SimpleCov::ResultMerger.store_result(result)
    end
  end
end

# rubocop:enable Metrics/MethodLength
