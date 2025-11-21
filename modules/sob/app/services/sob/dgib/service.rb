# frozen_string_literal: true

module SOB
  module DGIB
    class Service < ::Common::Client::Base
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.sob.dgib'

      def initialize(ssn)
        super()
        raise Common::Exceptions::ParameterMissing, 'SSN' if icn.blank?

        @ssn = ssn
      end

      def get_ch33_status
      end
    end
  end
end
