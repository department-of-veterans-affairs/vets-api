# frozen_string_literal: true

require 'bgs/service'
require 'mpi/service'
require 'evss/service'

OkComputer.mount_at = false
OkComputer.check_in_parallel = true

class EvssCheck < OkComputer::Check
  def check
    Settings.evss.mock_claims || EVSS::Service.service_is_up? ? process_success : process_failure
  rescue
    process_failure
  end

  private

  def process_success
    mark_message 'EVSS is running'
  end

  def process_failure
    mark_failure
    mark_message 'EVSS is unavailable'
  end
end

class MpiCheck < OkComputer::Check
  def check
    Settings.mvi.mock || MPI::Service.service_is_up? ? process_success : process_failure
  rescue
    process_failure
  end

  private

  def process_success
    mark_message 'MPI is running'
  end

  def process_failure
    mark_failure
    mark_message 'MPI is unavailable'
  end
end

class BgsCheck < OkComputer::Check
  def check
    service = BGS::Services.new(
      external_uid: 'healthcheck_uid',
      external_key: 'healthcheck_key'
    )
    service.vet_record.healthy? ? process_success : process_failure
  rescue
    process_failure
  end

  private

  def process_success
    mark_message 'BGS is running'
  end

  def process_failure
    mark_failure
    mark_message 'BGS is unavailable'
  end
end

class VbmsCheck < OkComputer::Check
  def check
    response = Faraday::Connection.new.get(Settings.vbms.url) { |request| request.options.timeout = 20 }
    response.status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  private

  def process_success
    mark_message 'VBMS is running'
  end

  def process_failure
    mark_failure
    mark_message 'VBMS is unavailable'
  end
end

OkComputer::Registry.register 'evss', EvssCheck.new
OkComputer::Registry.register 'mpi', MpiCheck.new
OkComputer::Registry.register 'bgs', BgsCheck.new
OkComputer::Registry.register 'vbms', VbmsCheck.new
