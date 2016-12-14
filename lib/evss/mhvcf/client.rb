# frozen_string_literal: true

require 'common/client/base'
require 'evss/mhvcf/configuration'

module EVSS
  module MHVCF
    class Client < Common::Client::Base
      configuration EVSS::MHVCF::Configuration

      def get_forms
        perform(:get, 'getInflightForms', nil).body
      end
    end
  end
end
