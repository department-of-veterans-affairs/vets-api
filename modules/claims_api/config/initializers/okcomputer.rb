# frozen_string_literal: true

require 'mpi/service'
require 'bgs_service/local_bgs'

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
    IdentitySettings.mvi.mock || MPI::Service.service_is_up? ? process_success : process_failure
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
OkComputer::Registry.register 'form-526-docker-container',
                              Form526DockerContainerCheck.new('wss-form526-services-web/tools/version.jsp')
OkComputer::Registry.register 'pdf-generator', PDFGenratorCheck.new('form-526ez-pdf-generator/actuator/health')
OkComputer::Registry.register 'localbgs-org',
                              FaradayBGSCheck.new('OrgWebServiceBean/OrgWebService')
OkComputer::Registry.register 'localbgs-trackeditem',
                              FaradayBGSCheck.new('TrackedItemService/TrackedItemService')

services = [
  { name: 'benefit_claim_service', endpoint: 'BenefitClaimServiceBean/BenefitClaimWebService' },
  { name: 'claimant_web_service', endpoint: 'ClaimantServiceBean/ClaimantWebService' },
  { name: 'claim_management_service', endpoint: 'ClaimManagementService/ClaimManagementService' },
  { name: 'contention_service', endpoint: 'ContentionService/ContentionService' },
  { name: 'corporate_update_web_service', endpoint: 'CorporateUpdateServiceBean/CorporateUpdateService' },
  { name: 'e_benefits_bnft_claim_status_web_service',
    endpoint: 'EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService' },
  { name: 'intent_to_file_web_service', endpoint: 'IntentToFileWebServiceBean/IntentToFileWebService' },
  { name: 'org_web_service', endpoint: 'OrgWebServiceBean/OrgWebService' },
  { name: 'person_web_service', endpoint: 'PersonWebServiceBean/PersonWebService' },
  { name: 'standard_data_service', endpoint: 'StandardDataService/StandardDataService' },
  { name: 'standard_data_web_service', endpoint: 'StandardDataWebServiceBean/StandardDataWebService' },
  { name: 'tracked_item_service', endpoint: 'TrackedItemService/TrackedItemService' },
  { name: 'vdc_manage_representative_service', endpoint: 'VDC/ManageRepresentativeService' },
  { name: 'vdc_veteran_representative_service', endpoint: 'VDC/VeteranRepresentativeService' },
  { name: 'vet_record_web_service', endpoint: 'VetRecordServiceBean/VetRecordWebService' },
  { name: 'vnp_atchms_service', endpoint: 'VnpAtchmsWebServiceBean/VnpAtchmsService' },
  { name: 'vnp_person_service', endpoint: 'VnpPersonWebServiceBean/VnpPersonService' },
  { name: 'vnp_proc_form_service', endpoint: 'VnpProcFormWebServiceBean/VnpProcFormService' },
  { name: 'vnp_proc_service_v2', endpoint: 'VnpProcWebServiceBeanV2/VnpProcServiceV2' },
  { name: 'vnp_ptcpnt_addrs_service', endpoint: 'VnpPtcpntAddrsWebServiceBean/VnpPtcpntAddrsService' },
  { name: 'vnp_ptcpnt_phone_service', endpoint: 'VnpPtcpntPhoneWebServiceBean/VnpPtcpntPhoneService' },
  { name: 'vnp_ptcpnt_service', endpoint: 'VnpPtcpntWebServiceBean/VnpPtcpntService' }
]
services.each do |service|
  OkComputer::Registry.register service[:name], FaradayBGSCheck.new(service[:endpoint])
end
