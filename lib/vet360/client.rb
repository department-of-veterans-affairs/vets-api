# frozen_string_literal: true

require 'common/client/base'
require 'vet360/configuration'

module Vet360
  # Core class responsible for api interface operations
  class Client < Common::Client::Base

    configuration Vet360::Configuration

    # CACHE_TTL = 3600 * 1 # 1 hour cache

    def get_bio(user)
      perform(:get, "#{user.vet360_id}", nil, cuf_system_name_header).body
    end

    private

    def cuf_system_name_header
      { cufSystemName: Settings.vet360.system_name }
    end

  end
end
