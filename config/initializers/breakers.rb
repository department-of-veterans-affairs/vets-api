# frozen_string_literal: true

require 'bb/configuration'
require 'breakers/statsd_plugin'
require 'caseflow/configuration'
require 'central_mail/configuration'
require 'debts/configuration'
require 'emis/military_information_configuration'
require 'emis/payment_configuration'
require 'emis/veteran_status_configuration'
require 'evss/claims_service'
require 'evss/common_service'
require 'evss/dependents/configuration'
require 'evss/disability_compensation_form/configuration'
require 'evss/documents_service'
require 'evss/letters/service'
require 'evss/gi_bill_status/service'
require 'evss/pciu_address/configuration'
require 'evss/reference_data/configuration'
require 'facilities/bulk_configuration'
require 'facilities/ppms/configuration'
require 'gi/configuration'
require 'gibft/configuration'
require 'hca/configuration'
require 'mhv_ac/configuration'
require 'mvi/configuration'
require 'preneeds/configuration'
require 'rx/configuration'
require 'sm/configuration'
require 'search/configuration'
require 'okta/configuration'
require 'vet360/contact_information/configuration'

# Read the redis config, create a connection and a namespace for breakers
# .to_h because hashes from config_for don't support non-symbol keys
redis_options = REDIS_CONFIG[:redis].to_h
redis_namespace = Redis::Namespace.new('breakers', redis: Redis.new(redis_options))

services = [
  Debts::Configuration.instance.breakers_service,
  Caseflow::Configuration.instance.breakers_service,
  DecisionReview::Configuration.instance.breakers_service,
  Rx::Configuration.instance.breakers_service,
  BB::Configuration.instance.breakers_service,
  EMIS::MilitaryInformationConfiguration.instance.breakers_service,
  EMIS::PaymentConfiguration.instance.breakers_service,
  EMIS::VeteranStatusConfiguration.instance.breakers_service,
  EVSS::ClaimsService.breakers_service,
  EVSS::CommonService.breakers_service,
  EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service,
  EVSS::DocumentsService.breakers_service,
  EVSS::Letters::Configuration.instance.breakers_service,
  EVSS::PCIUAddress::Configuration.instance.breakers_service,
  EVSS::GiBillStatus::Configuration.instance.breakers_service,
  EVSS::Dependents::Configuration.instance.breakers_service,
  EVSS::ReferenceData::Configuration.instance.breakers_service,
  Gibft::Configuration.instance.breakers_service,
  Facilities::AccessWaitTimeConfiguration.instance.breakers_service,
  Facilities::AccessSatisfactionConfiguration.instance.breakers_service,
  Facilities::PPMS::Configuration.instance.breakers_service,
  GI::Configuration.instance.breakers_service,
  HCA::Configuration.instance.breakers_service,
  MHVAC::Configuration.instance.breakers_service,
  MVI::Configuration.instance.breakers_service,
  Preneeds::Configuration.instance.breakers_service,
  SM::Configuration.instance.breakers_service,
  Vet360::ContactInformation::Configuration.instance.breakers_service,
  Search::Configuration.instance.breakers_service,
  Okta::Configuration.instance.breakers_service,
  VAOS::Configuration.instance.breakers_service
]

services << CentralMail::Configuration.instance.breakers_service if Settings.central_mail&.upload&.enabled

plugin = Breakers::StatsdPlugin.new

client = Breakers::Client.new(
  redis_connection: redis_namespace,
  services: services,
  logger: Rails.logger,
  plugins: [plugin]
)

# No need to prefix it when using the namespace
Breakers.redis_prefix = ''
Breakers.client = client
Breakers.disabled = true if Settings.breakers_disabled
