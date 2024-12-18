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
  def initialize(bean, service)
    @bean = bean
    @service = service
    @endpoint = "#{bean}/#{service}"
  end

  def check
    service = eval("ClaimsApi::#{@service} = Class.new")
    faraday_service = service.new(
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
# new bgs services 12/24
OkComputer::Registry.register 'claimant-service',
                              BGSServiceCheck.new('ClaimantServiceBean', 'ClaimantWebService')
OkComputer::Registry.register 'contention-service',
                              BGSServiceCheck.new('ContentionServiceBean', 'ContentionService')
OkComputer::Registry.register 'corporate-update-web-service',
                              BGSServiceCheck.new('CorporateUpdateServiceBean', 'CorporateUpdateService')
OkComputer::Registry.register 'e-benefits-bnft-claim-status-web-service',
                              BGSServiceCheck.new(
                                'EBenefitsBnftClaimStatusWebServiceBean', 'EBenefitsBenefitClaimStatusWebService'
                              )
OkComputer::Registry.register 'intent-to-file-service',
                              BGSServiceCheck.new('IntentToFileWebServiceBean', 'IntentToFileWebService')
# future service
# OkComputer::Registry.register 'org-web-service', BGSServiceCheck.new('OrgWebServiceBean','OrgWebService')
OkComputer::Registry.register 'person-web-service', BGSServiceCheck.new('PersonWebServiceBean', 'PersonWebService')
OkComputer::Registry.register 'standard-data-service', BGSServiceCheck.new('StandardDataService', 'StandardDataService')
# future service
# OkComputer::Registry.register 'standard-data-web-service',
#                               BGSServiceCheck.new('StandardDataWebServiceBean','StandardDataWebService')
OkComputer::Registry.register 'tracked-item-service', BGSServiceCheck.new('TrackedItemService', 'TrackedItemService')
OkComputer::Registry.register 'manage-rep-service', BGSServiceCheck.new('VDC', 'ManageRepresentativeService')
OkComputer::Registry.register 'vet-rep-service', BGSServiceCheck.new('VDC', 'VeteranRepresentativeService')
OkComputer::Registry.register 'vet-record-service', BGSServiceCheck.new('VetRecordServiceBean', 'VetRecordWebService')
OkComputer::Registry.register 'vnp-atchms-web-service',
                              BGSServiceCheck.new('VnpAtchmsWebServiceBean', 'VnpAtchmsService')
OkComputer::Registry.register 'vnp-person-web-service',
                              BGSServiceCheck.new('VnpPersonWebServiceBean', 'VnpPersonService')
OkComputer::Registry.register 'vnp-proc-form-web-service',
                              BGSServiceCheck.new('VnpProcFormWebServiceBean', 'VnpProcFormService')
OkComputer::Registry.register 'vnp-proc-web-v2-service',
                              BGSServiceCheck.new('VnpProcWebServiceBeanV2', 'VnpProcServiceV2')
OkComputer::Registry.register 'vnp-ptcpnt-addrs-web-service',
                              BGSServiceCheck.new('VnpPtcpntAddrsWebServiceBean', 'VnpPtcpntAddrsService')
OkComputer::Registry.register 'vnp-ptcpnt-phone-service',
                              BGSServiceCheck.new('VnpPtcpntPhoneWebServiceBean', 'VnpPtcpntPhoneService')
OkComputer::Registry.register 'vnp-ptcpnt-web-service',
                              BGSServiceCheck.new('VnpPtcpntWebServiceBean', 'VnpPtcpntService')
