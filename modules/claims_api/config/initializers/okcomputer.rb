# frozen_string_literal: true

require 'bgs/service'
require 'mpi/service'
require 'evss/service'

OkComputer.mount_at = false
OkComputer.check_in_parallel = true

class EvssCheck < OkComputer::Check
  def check
    if Settings.evss.mock_claims || EVSS::Service.service_is_up?
      mark_message 'EVSS is running'
    else
      mark_failure
      mark_message 'EVSS is unavailable'
    end
  rescue
    mark_failure
    mark_message 'EVSS is unavailable'
  end
end
OkComputer::Registry.register 'evss', EvssCheck.new

class MpiCheck < OkComputer::Check
  def check
    if Settings.mvi.mock || MPI::Service.service_is_up?
      mark_message 'MPI is running'
    else
      mark_failure
      mark_message 'MPI is unavailable'
    end
  rescue
    mark_failure
    mark_message 'MPI is unavailable'
  end
end
OkComputer::Registry.register 'mpi', MpiCheck.new

class BgsCheck < OkComputer::Check
  def check
    service = BGS::Services.new(
      external_uid: 'healthcheck_uid',
      external_key: 'healthcheck_key'
    )

    if service.vet_record.healthy?
      mark_message 'BGS is running'
    else
      mark_failure
      mark_message 'BGS is unavailable'
    end
  rescue
    mark_failure
    mark_message 'BGS is unavailable'
  end
end
OkComputer::Registry.register 'bgs', BgsCheck.new

class VbmsCheck < OkComputer::Check
  def check
    response = Faraday::Connection.new.get(Settings.vbms.url) { |request| request.options.timeout = 20 }

    if response.status == 200
      mark_message 'VBMS is running'
    else
      mark_failure
      mark_message 'VBMS is unavailable'
    end
  rescue
    mark_failure
    mark_message 'VBMS is unavailable'
  end
end
OkComputer::Registry.register 'vbms', VbmsCheck.new
