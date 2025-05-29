# frozen_string_literal: true

require 'bb/configuration'
require 'breakers/statsd_plugin'
require 'caseflow/configuration'
require 'central_mail/configuration'
require 'debt_management_center/debts_configuration'
require 'decision_review/configuration'
require 'vye/dgib/service'
require 'dgi/automation/configuration'
require 'dgi/eligibility/configuration'
require 'dgi/status/configuration'
require 'dgi/submission/configuration'
require 'dgi/letters/configuration'
require 'evss/claims_service'
require 'evss/common_service'
require 'evss/dependents/configuration'
require 'evss/disability_compensation_form/configuration'
require 'evss/documents_service'
require 'evss/letters/service'
require 'evss/pciu_address/configuration'
require 'gi/configuration'
require 'gibft/configuration'
require 'hca/configuration'
require 'lighthouse/benefits_education/configuration'
require 'mdot/configuration'
require 'mhv_ac/configuration'
require 'mpi/configuration'
require 'pagerduty/configuration'
require 'post911_sob/dgib/configuration'
require 'preneeds/configuration'
require 'rx/configuration'
require 'sm/configuration'
require 'search/configuration'
require 'search_gsa/configuration'
require 'search_typeahead/configuration'
require 'search_click_tracking/configuration'
require 'va_profile/address_validation/configuration'
require 'va_profile/v3/address_validation/configuration'
require 'va_profile/contact_information/configuration'
require 'va_profile/v2/contact_information/configuration'
require 'va_profile/communication/configuration'
require 'va_profile/demographics/configuration'
require 'va_profile/military_personnel/configuration'
require 'va_profile/veteran_status/configuration'
require 'iam_ssoe_oauth/configuration'
require 'vetext/service'
require 'veteran_enrollment_system/associations/configuration'
require 'veteran_enrollment_system/base_configuration'
require 'unified_health_data/configuration'

Rails.application.reloader.to_prepare do
  redis_namespace = Redis::Namespace.new('breakers', redis: $redis)

  services = [
    DebtManagementCenter::DebtsConfiguration.instance.breakers_service,
    Caseflow::Configuration.instance.breakers_service,
    DecisionReview::Configuration.instance.breakers_service,
    Rx::Configuration.instance.breakers_service,
    BB::Configuration.instance.breakers_service,
    BenefitsEducation::Configuration.instance.breakers_service,
    EVSS::ClaimsService.breakers_service,
    EVSS::CommonService.breakers_service,
    EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service,
    EVSS::DocumentsService.breakers_service,
    EVSS::Letters::Configuration.instance.breakers_service,
    EVSS::PCIUAddress::Configuration.instance.breakers_service,
    EVSS::Dependents::Configuration.instance.breakers_service,
    Gibft::Configuration.instance.breakers_service,
    GI::Configuration.instance.breakers_service,
    HCA::Configuration.instance.breakers_service,
    MHVAC::Configuration.instance.breakers_service,
    MPI::Configuration.instance.breakers_service,
    Post911SOB::DGIB::Configuration.instance.breakers_service,
    Preneeds::Configuration.instance.breakers_service,
    SM::Configuration.instance.breakers_service,
    VeteranEnrollmentSystem::Associations::Configuration.instance.breakers_service,
    VeteranEnrollmentSystem::BaseConfiguration.instance.breakers_service,
    VAProfile::AddressValidation::Configuration.instance.breakers_service,
    VAProfile::V3::AddressValidation::Configuration.instance.breakers_service,
    VAProfile::ContactInformation::Configuration.instance.breakers_service,
    VAProfile::V2::ContactInformation::Configuration.instance.breakers_service,
    VAProfile::Communication::Configuration.instance.breakers_service,
    VAProfile::Demographics::Configuration.instance.breakers_service,
    VAProfile::MilitaryPersonnel::Configuration.instance.breakers_service,
    VAProfile::VeteranStatus::Configuration.instance.breakers_service,
    Search::Configuration.instance.breakers_service,
    SearchGsa::Configuration.instance.breakers_service,
    SearchTypeahead::Configuration.instance.breakers_service,
    SearchClickTracking::Configuration.instance.breakers_service,
    VAOS::Configuration.instance.breakers_service,
    Vye::DGIB::Configuration.instance.breakers_service,
    IAMSSOeOAuth::Configuration.instance.breakers_service,
    VEText::Configuration.instance.breakers_service,
    PagerDuty::Configuration.instance.breakers_service,
    ClaimsApi::LocalBGS.breakers_service,
    MebApi::DGI::Configuration.instance.breakers_service,
    MebApi::DGI::Letters::Configuration.instance.breakers_service,
    UnifiedHealthData::Configuration.instance.breakers_service,
    MDOT::Configuration.instance.breakers_service
  ]

  services << CentralMail::Configuration.instance.breakers_service if Settings.central_mail&.upload&.enabled

  plugin = Breakers::StatsdPlugin.new

  client = Breakers::Client.new(
    redis_connection: redis_namespace,
    services:,
    logger: Rails.logger,
    plugins: [plugin]
  )

  # No need to prefix it when using the namespace
  Breakers.redis_prefix = ''
  Breakers.client = client
  Breakers.disabled = true if Settings.breakers_disabled

  Breakers.config&.outage_exceptions += [
    Common::Exceptions::BackendServiceException
  ]
end
