# frozen_string_literal: true

# spec/simplecov_helper.rb
require 'active_support/inflector'
require 'simplecov'
require_relative 'support/codeowners_parser'

class SimpleCovHelper
  def self.start_coverage
    SimpleCov.start 'rails' do
      ENV.fetch('SKIP_COVERAGE_CHECK', 'false')
      print(ENV.fetch('TEST_ENV_NUMBER', nil))
      # parallel_tests_count = ParallelTests.number_of_running_processes
      # SimpleCov.command_name "(#{ENV['TEST_ENV_NUMBER'] || '1'}/#{parallel_tests_count})"

      SimpleCov.command_name "rspec-#{ENV['TEST_ENV_NUMBER'] || '0'}"
      track_files '{app,lib}/**/*.rb'

      add_filters
      add_modules
      # parse_codeowners

      # skip_check_coverage = ENV.fetch('SKIP_COVERAGE_CHECK', 'false')
      # minimum_coverage(90) unless skip_check_coverage
      # refuse_coverage_drop unless skip_check_coverage
      # merge_timeout(3600)
      if ENV['CI']
        SimpleCov.minimum_coverage 90
        SimpleCov.refuse_coverage_drop
      end
    end

    if ENV['TEST_ENV_NUMBER'] # parallel specs
      SimpleCov.at_exit do
        # SimpleCovHelper.report_coverage
        result = SimpleCov.result
        result.format!
        # SimpleCovHelper.report_coverage # merge and format
      end
    end
  end

  def self.report_coverage(base_dir: './coverage')
    SimpleCov.collate Dir["#{base_dir}/.resultset*.json"] do
      add_filters
      add_modules
    end
  rescue RuntimeError
    nil
  end

  def self.add_filters
    add_filter 'app/models/in_progress_disability_compensation_form.rb'
    add_filter 'lib/apps/configuration.rb'
    add_filter 'lib/apps/responses/response.rb'
    add_filter 'lib/config_helper.rb'
    add_filter 'lib/clamav'
    add_filter 'lib/feature_flipper.rb'
    add_filter 'lib/gibft/configuration.rb'
    add_filter 'lib/salesforce/configuration.rb'
    add_filter 'lib/search/response.rb'
    add_filter 'lib/search_gsa/response.rb'
    add_filter 'lib/va_profile/v3/address_validation/configuration.rb'
    add_filter 'lib/va_profile/exceptions/builder.rb'
    add_filter 'lib/va_profile/response.rb'
    add_filter 'lib/vet360/address_validation/configuration.rb'
    add_filter 'lib/vet360/exceptions/builder.rb'
    add_filter 'lib/vet360/response.rb'
    add_filter 'lib/rubocop/*'
    add_filter 'modules/appeals_api/app/swagger'
    add_filter 'modules/apps_api/app/controllers/apps_api/docs/v0/api_controller.rb'
    add_filter 'modules/apps_api/app/swagger'
    add_filter 'modules/burials/lib/benefits_intake/submission_handler.rb'
    add_filter 'modules/check_in/config/initializers/statsd.rb'
    add_filter 'modules/claims_api/app/controllers/claims_api/v1/forms/disability_compensation_controller.rb'
    add_filter 'modules/claims_api/app/swagger/*'
    add_filter 'modules/pensions/app/swagger'
    add_filter 'modules/pensions/lib/benefits_intake/submission_handler.rb'
    add_filter 'modules/vre/app/services/vre'
    add_filter 'modules/**/db/*'
    add_filter 'modules/**/lib/tasks/*'
    add_filter 'rakelib/'
    add_filter '**/rakelib/**/*'
    add_filter '**/rakelib/*'
    add_filter 'version.rb'
  end

  def self.add_modules
    # Modules
    add_group 'AccreditedRepresentativePortal', 'modules/accredited_representative_portal/'
    add_group 'AppealsApi', 'modules/appeals_api/'
    add_group 'AppsApi', 'modules/apps_api'
    add_group 'AskVAApi', 'modules/ask_va_api/'
    add_group 'Avs', 'modules/avs/'
    add_group 'BPDS', 'modules/bpds/'
    add_group 'Banners', 'modules/banners/'
    add_group 'Burials', 'modules/burials/'
    add_group 'CheckIn', 'modules/check_in/'
    add_group 'ClaimsApi', 'modules/claims_api/'
    add_group 'ClaimsEvidenceApi', 'modules/claims_evidence_api/'
    add_group 'CovidResearch', 'modules/covid_research/'
    add_group 'DebtsApi', 'modules/debts_api/'
    add_group 'DecisionReviews', 'modules/decision_reviews'
    add_group 'DependentsBenefits', 'modules/dependents_benefits/'
    add_group 'DependentsVerification', 'modules/dependents_verification/'
    add_group 'DhpConnectedDevices', 'modules/dhp_connected_devices/'
    add_group 'DigitalFormsApi', 'modules/digital_forms_api/'
    add_group 'FacilitiesApi', 'modules/facilities_api/'
    add_group 'IncomeAndAssets', 'modules/income_and_assets/'
    add_group 'IncreaseCompensation', 'modules/increase_compensation/'
    add_group 'IvcChampva', 'modules/ivc_champva/'
    add_group 'MedicalExpenseReports', 'modules/medical_expense_reports/'
    add_group 'RepresentationManagement', 'modules/representation_management/'
    add_group 'SimpleFormsApi', 'modules/simple_forms_api/'
    add_group 'IncomeLimits', 'modules/income_limits/'
    add_group 'MebApi', 'modules/meb_api/'
    add_group 'Mobile', 'modules/mobile/'
    add_group 'MyHealth', 'modules/my_health/'
    add_group 'Pensions', 'modules/pensions/'
    add_group 'Policies', 'app/policies'
    add_group 'Serializers', 'app/serializers'
    add_group 'Services', 'app/services'
    add_group 'Sob', 'modules/sob/'
    add_group 'SurvivorsBenefits', 'modules/survivors_benefits/'
    add_group 'Swagger', 'app/swagger'
    add_group 'TestUserDashboard', 'modules/test_user_dashboard/'
    add_group 'TravelPay', 'modules/travel_pay/'
    add_group 'Uploaders', 'app/uploaders'
    add_group 'VRE', 'modules/vre/'
    add_group 'VaNotify', 'modules/va_notify/'
    add_group 'VAOS', 'modules/vaos/'
    add_group 'VBADocuments', 'modules/vba_documents/'
    add_group 'Veteran', 'modules/veteran/'
    add_group 'VeteranVerification', 'modules/veteran_verification/'
    add_group 'Vye', 'modules/vye/'
  end

  def self.parse_codeowners
    # Team Groups
    codeowners_parser = CodeownersParser.new
    octo_identity_files = codeowners_parser.perform('octo-identity')
    add_group 'OctoIdentity', octo_identity_files
  end
end
