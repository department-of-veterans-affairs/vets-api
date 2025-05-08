# frozen_string_literal: true

# spec/simplecov_helper.rb
require 'active_support/inflector'
require 'simplecov'

class SimpleCovHelper
  def self.report_coverage(base_dir: './coverage_results')
    SimpleCov.start 'rails' do
      skip_check_coverage = ENV.fetch('SKIP_COVERAGE_CHECK', 'false')

      track_files '**/{app,lib}/**/*.rb'

      add_filters
      add_modules

      minimum_coverage(90) unless skip_check_coverage
      refuse_coverage_drop unless skip_check_coverage
      merge_timeout(3600)
    end
    new(base_dir:).merge_results
  end

  attr_reader :base_dir

  def initialize(base_dir:)
    @base_dir = base_dir
  end

  def all_results
    Dir["#{base_dir}/.resultset*.json"]
  end

  def merge_results
    SimpleCov.collate all_results
  rescue RuntimeError
    nil
  end

  def self.add_filters
    add_filter 'app/controllers/concerns/accountable.rb'
    add_filter 'lib/apps/configuration.rb'
    add_filter 'lib/apps/responses/response.rb'
    add_filter 'lib/config_helper.rb'
    add_filter 'lib/feature_flipper.rb'
    add_filter 'lib/gibft/configuration.rb'
    add_filter 'lib/ihub/appointments/response.rb'
    add_filter 'lib/salesforce/configuration.rb'
    add_filter 'lib/vet360/address_validation/configuration.rb'
    add_filter 'lib/search/response.rb'
    add_filter 'lib/vet360/exceptions/builder.rb'
    add_filter 'lib/vet360/response.rb'
    add_filter 'modules/claims_api/app/controllers/claims_api/v1/forms/disability_compensation_controller.rb'
    add_filter 'modules/claims_api/app/swagger/*'
    add_filter 'version.rb'
  end

  def self.add_modules
    # Modules
    add_group 'AccreditedRepresentativePortal', 'modules/accredited_representative_portal/'
    add_group 'AppealsApi', 'modules/appeals_api/'
    add_group 'AskVAApi', 'modules/ask_va_api/'
    add_group 'Avs', 'modules/avs/'
    add_group 'Banners', 'modules/banners/'
    add_group 'CheckIn', 'modules/check_in/'
    add_group 'ClaimsApi', 'modules/claims_api/'
    add_group 'DebtsApi', 'modules/debts_api/'
    add_group 'DhpConnectedDevices', 'modules/dhp_connected_devices/'
    add_group 'FacilitiesApi', 'modules/facilities_api/'
    add_group 'IncomeAndAssets', 'modules/income_and_assets/'
    add_group 'IvcChampva', 'modules/ivc_champva/'
    add_group 'RepresentationManagement', 'modules/representation_management/'
    add_group 'SimpleFormsApi', 'modules/simple_forms_api/'
    add_group 'HealthQuest', 'modules/health_quest'
    add_group 'IncomeLimits', 'modules/income_limits/'
    add_group 'MebApi', 'modules/meb_api/'
    add_group 'MyHealth', 'modules/my_health/'
    add_group 'Pensions', 'modules/pensions/'
    add_group 'Policies', 'app/policies'
    add_group 'Serializers', 'app/serializers'
    add_group 'Services', 'app/services'
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
end
