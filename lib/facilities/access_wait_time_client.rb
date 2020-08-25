# frozen_string_literal: true

require 'common/client/base'
require 'facilities/bulk_configuration'

module Facilities
  class AccessWaitTimeClient < Common::Client::Base
    configuration Facilities::AccessWaitTimeConfiguration

    def download
      perform(:get, 'atcapis/v1.1/patientwaittimes', {}, nil).body
    end
  end
end
