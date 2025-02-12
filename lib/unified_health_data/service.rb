# frozen_string_literal: true
require 'common/client/base'
require_relative 'configuration'

module UnifiedHealthData
  class Service < Common::Client::Base
    configuration UnifiedHealthData::Configuration

    def get_medical_records
      perform(:get, 'path/to/medical_records')
    end
  end
end
