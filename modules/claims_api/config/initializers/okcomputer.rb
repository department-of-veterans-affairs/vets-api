# frozen_string_literal: true

require 'mpi/service'
require 'bgs_service/local_bgs'
require 'bgs_service/benefit_claim_service'
require 'bgs_service/claimant_web_service'
require 'bgs_service/claim_management_service'
require 'bgs_service/contention_service'
require 'bgs_service/corporate_update_web_service'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'
require 'bgs_service/intent_to_file_web_service'
require 'bgs_service/manage_representative_service'
require 'bgs_service/person_web_service'
require 'bgs_service/standard_data_service'
require 'bgs_service/vet_record_web_service'
require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_atchms_service'
require 'bgs_service/vnp_person_service'
require 'bgs_service/vnp_proc_form_service'
require 'bgs_service/vnp_proc_service_v2'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require 'bgs_service/vnp_ptcpnt_phone_service'
require 'bgs_service/vnp_ptcpnt_service'

OkComputer.mount_at = false
OkComputer.check_in_parallel = true

class BaseCheck < OkComputer::Check
  protected

  def name
    'Unknown'
  end

  def process_success
    mark_message "#{name} is running"
  end

  def process_failure
    mark_failure
    mark_message "#{name} is unavailable"
  end
end

class MpiCheck < BaseCheck
  def check
    Settings.mvi.mock || MPI::Service.service_is_up? ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'MPI'
  end
end

class FaradayBGSCheck < BaseCheck
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def check
    faraday_service = ClaimsApi::LocalBGS.new(
      external_uid: 'healthcheck_uid',
      external_key: 'healthcheck_key'
    )
    status = faraday_service.send('healthcheck', @endpoint)
    status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    "Faraday BGS #{@endpoint}"
  end
end

class BeneftsDocumentsCheck < BaseCheck
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def check
    base_name = Settings.claims_api.benefits_documents.host
    url = "#{base_name}/#{@endpoint}"
    res = faraday_client.get(url)
    res.status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'Benefits Documents V1'
  end
end

class Form526DockerContainerCheck < BaseCheck
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def check
    base_name = Settings.evss&.dvp&.url
    url = "#{base_name}/#{@endpoint}"
    res = faraday_client.get(url)
    res.status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'Form 526 Docker Container'
  end
end

class PDFGenratorCheck < BaseCheck
  def initialize(endpoint)
    @endpoint = endpoint
  end

  def check
    base_name = Settings.claims_api.pdf_generator_526.url
    url = "#{base_name}/#{@endpoint}"
    res = faraday_client.get(url)
    res.status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'PDF Generator'
  end
end

class BGSServiceCheck < BaseCheck
  def initialize(bean, service, class_name)
    @bean = bean
    @service = service
    @class_name = class_name
    @endpoint = "#{bean}/#{service}"
  end

  def check
    faraday_service = @class_name.new(
      external_uid: 'healthcheck_uid',
      external_key: 'healthcheck_key'
    )
    status = faraday_service.send('healthcheck', @endpoint)
    status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    "Faraday BGS #{@service}"
  end
end

def faraday_client
  Faraday.new( # Disable SSL for (localhost) testing
    ssl: { verify: !Rails.env.development? }
  ) do |f|
    f.request :json
    f.response :betamocks if @use_mock
    f.response :raise_custom_error
    f.response :json, parser_options: { symbolize_names: true }
    f.adapter Faraday.default_adapter
  end
end

OkComputer::Registry.register 'mpi', MpiCheck.new
OkComputer::Registry.register 'benefits-documents',
                              BeneftsDocumentsCheck.new('services/benefits-documents/v1/healthcheck')
OkComputer::Registry.register 'form-526-docker-container',
                              Form526DockerContainerCheck.new('wss-form526-services-web/tools/version.jsp')
OkComputer::Registry.register 'pdf-generator', PDFGenratorCheck.new('form-526ez-pdf-generator/actuator/health')
OkComputer::Registry.register 'localbgs-org',
                              FaradayBGSCheck.new('OrgWebServiceBean/OrgWebService')
OkComputer::Registry.register 'localbgs-trackeditem',
                              FaradayBGSCheck.new('TrackedItemService/TrackedItemService')

# new bgs services 12/2024
OkComputer::Registry.register 'benefit-claim-web-service', BGSServiceCheck.new(
  'BenefitClaimServiceBean', 'BenefitClaimWebService', ClaimsApi::BenefitClaimService
)
OkComputer::Registry.register 'claim-management-service', BGSServiceCheck.new(
  'ClaimManagementService', 'ClaimManagementService', ClaimsApi::ClaimManagementService
)
OkComputer::Registry.register 'claimant-service', BGSServiceCheck.new(
  'ClaimantServiceBean', 'ClaimantWebService', ClaimsApi::ClaimantWebService
)
OkComputer::Registry.register 'contention-service', BGSServiceCheck.new(
  'ContentionService', 'ContentionService', ClaimsApi::ContentionService
)
OkComputer::Registry.register 'corporate-update-web-service', BGSServiceCheck.new(
  'CorporateUpdateServiceBean', 'CorporateUpdateService', ClaimsApi::CorporateUpdateWebService
)
OkComputer::Registry.register 'e-benefits-bnft-claim-status-web-service', BGSServiceCheck.new(
  'EBenefitsBnftClaimStatusWebServiceBean', 'EBenefitsBnftClaimStatusWebService',
  ClaimsApi::EbenefitsBnftClaimStatusWebService
)
OkComputer::Registry.register 'intent-to-file-service', BGSServiceCheck.new(
  'IntentToFileWebServiceBean', 'IntentToFileWebService', ClaimsApi::IntentToFileWebService
)
OkComputer::Registry.register 'manage-rep-service', BGSServiceCheck.new(
  'VDC', 'ManageRepresentativeService', ClaimsApi::ManageRepresentativeService
)
# future service
# OkComputer::Registry.register 'org-web-service', BGSServiceCheck.new(
# 'OrgWebServiceBean','OrgWebService', ClaimsApi::OrgWebService)
OkComputer::Registry.register 'person-web-service', BGSServiceCheck.new(
  'PersonWebServiceBean', 'PersonWebService', ClaimsApi::PersonWebService
)
OkComputer::Registry.register 'standard-data-service', BGSServiceCheck.new(
  'StandardDataService', 'StandardDataService', ClaimsApi::StandardDataService
)
# future services
# OkComputer::Registry.register 'standard-data-web-service', BGSServiceCheck.new(
# 'StandardDataWebServiceBean','StandardDataWebService', ClaimsApi::StandardDataWebService
# )
# OkComputer::Registry.register 'tracked-item-service', BGSServiceCheck.new(
#   'TrackedItemService', 'TrackedItemService', ClaimsApi::TrackedItemService
# )
OkComputer::Registry.register 'vet-rep-service', BGSServiceCheck.new(
  'VDC', 'VeteranRepresentativeService', ClaimsApi::VeteranRepresentativeService
)
OkComputer::Registry.register 'vet-record-service', BGSServiceCheck.new(
  'VetRecordServiceBean', 'VetRecordWebService', ClaimsApi::VetRecordWebService
)
OkComputer::Registry.register 'vnp-atchms-web-service', BGSServiceCheck.new(
  'VnpAtchmsWebServiceBean', 'VnpAtchmsService', ClaimsApi::VnpAtchmsService
)
OkComputer::Registry.register 'vnp-person-web-service', BGSServiceCheck.new(
  'VnpPersonWebServiceBean', 'VnpPersonService', ClaimsApi::VnpPersonService
)
OkComputer::Registry.register 'vnp-proc-form-web-service', BGSServiceCheck.new(
  'VnpProcFormWebServiceBean', 'VnpProcFormService', ClaimsApi::VnpProcFormService
)
OkComputer::Registry.register 'vnp-proc-service-v2', BGSServiceCheck.new(
  'VnpProcWebServiceBeanV2', 'VnpProcServiceV2', ClaimsApi::VnpProcServiceV2
)
OkComputer::Registry.register 'vnp-ptcpnt-addrs-service', BGSServiceCheck.new(
  'VnpPtcpntAddrsWebServiceBean', 'VnpPtcpntAddrsService', ClaimsApi::VnpPtcpntAddrsService
)
OkComputer::Registry.register 'vnp-ptcpnt-phone-service', BGSServiceCheck.new(
  'VnpPtcpntPhoneWebServiceBean', 'VnpPtcpntPhoneService', ClaimsApi::VnpPtcpntPhoneService
)
OkComputer::Registry.register 'vnp-ptcpnt-service', BGSServiceCheck.new(
  'VnpPtcpntWebServiceBean', 'VnpPtcpntService', ClaimsApi::VnpPtcpntService
)
