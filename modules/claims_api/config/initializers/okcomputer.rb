# frozen_string_literal: true

require 'bgs/services'
require 'mpi/service'
require 'evss/service'
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

class EvssCheck < BaseCheck
  def check
    Settings.evss.mock_claims || EVSS::Service.service_is_up? ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'EVSS'
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

class BgsCheck < BaseCheck
  def initialize(service)
    @service = service
  end

  def check
    service = BGS::Services.new(
      external_uid: 'healthcheck_uid',
      external_key: 'healthcheck_key'
    )
    service.send(@service).healthy? ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    "BGS #{@service}"
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

class VbmsCheck < BaseCheck
  def check
    connection = Faraday::Connection.new
    connection.options.timeout = 10
    response = connection.get("#{Settings.vbms.url}/vbms-efolder-svc/upload-v1/eFolderUploadService?wsdl")
    response.status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'VBMS'
  end
end

OkComputer::Registry.register 'evss', EvssCheck.new
OkComputer::Registry.register 'mpi', MpiCheck.new
OkComputer::Registry.register 'bgs-vet_record', BgsCheck.new('vet_record')
OkComputer::Registry.register 'bgs-corporate_update', BgsCheck.new('corporate_update')
OkComputer::Registry.register 'bgs-contention', BgsCheck.new('contention')

OkComputer::Registry.register 'localbgs-claimant',
                              FaradayBGSCheck.new('ClaimantServiceBean/ClaimantWebService')
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

OkComputer::Registry.register 'vbms', VbmsCheck.new

OkComputer.make_optional %w[vbms bgs-vet_record bgs-corporate_update bgs-contention]
