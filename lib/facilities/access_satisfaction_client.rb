# frozen_string_literal: true

require 'common/client/base'
require 'facilities/bulk_configuration'

module Facilities
  class AccessSatisfactionClient < Common::Client::Base
    configuration Facilities::AccessSatisfactionConfiguration

    def download
      query = { 'location' => '*' }
      perform(:get, 'Shep/getRawData', query, nil).body
    end
  end
end
