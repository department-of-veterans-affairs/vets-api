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
OkComputer::Registry.register 'localbgs-claimant',
                              FaradayBGSCheck.new('ClaimantServiceBean/ClaimantWebService')
OkComputer::Registry.register 'localbgs-corporate_update',
                              FaradayBGSCheck.new('CorporateUpdateServiceBean/CorporateUpdateWebService')
OkComputer::Registry.register 'localbgs-person',
                              FaradayBGSCheck.new('PersonWebServiceBean/PersonWebService')
OkComputer::Registry.register 'localbgs-org',
                              FaradayBGSCheck.new('OrgWebServiceBean/OrgWebService')
# rubocop:disable Layout/LineLength
OkComputer::Registry.register 'localbgs-ebenefitsbenftclaim',
                              FaradayBGSCheck.new('EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService')
# rubocop:enable Layout/LineLength
OkComputer::Registry.register 'localbgs-intenttofile',
                              FaradayBGSCheck.new('IntentToFileWebServiceBean/IntentToFileWebService')
OkComputer::Registry.register 'localbgs-trackeditem',
                              FaradayBGSCheck.new('TrackedItemService/TrackedItemService')
OkComputer::Registry.register 'benefits-documents',
                              BeneftsDocumentsCheck.new('services/benefits-documents/v1/healthcheck')
OkComputer::Registry.register 'form-526-docker-container',
                              Form526DockerContainerCheck.new('wss-form526-services-web/tools/version.jsp')
OkComputer::Registry.register 'pdf-generator', PDFGenratorCheck.new('form-526ez-pdf-generator/actuator/health')
