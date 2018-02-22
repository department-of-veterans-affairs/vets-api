# frozen_string_literal: true

require 'common/client/base'
require 'facilities/bulk_configuration'

module Facilities
  class AccessWaitTimeClient < Common::Client::Base
    configuration Facilities::AccessWaitTimeConfiguration

    def download
      query = { 'location' => '*' }
      perform(:get, 'Main/getRawData', query, nil).body
    end
  end

  class AccessSatisfactionClient < Common::Client::Base
    configuration Facilities::AccessSatisfactionConfiguration

    def download
      query = { 'location' => '*' }
      perform(:get, 'Main/getRawData', query, nil).body
    end
  end
end
