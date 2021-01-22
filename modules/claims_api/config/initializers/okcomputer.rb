# frozen_string_literal: true

require 'bgs/service'
require 'mpi/service'
require 'evss/service'

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

class VbmsCheck < BaseCheck
  def check
    response = Faraday::Connection.new.get(Settings.vbms.url) { |request| request.options.timeout = 20 }
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
OkComputer::Registry.register 'bgs-intent_to_file', BgsCheck.new('intent_to_file')
OkComputer::Registry.register 'bgs-claimant', BgsCheck.new('claimant')
OkComputer::Registry.register 'bgs-contention', BgsCheck.new('contention')
OkComputer::Registry.register 'vbms', VbmsCheck.new

OkComputer.make_optional %w[vbms bgs-vet_record bgs-claimant bgs-contention]
