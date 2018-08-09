# frozen_string_literal: true

module EVSS
  module Dependents
    class Configuration < EVSS::Configuration
      def base_path
        "http://internal-dsva-vetsgov-stag-forward-proxy-1891752030.us-gov-west-1.elb.amazonaws.com/wss-686-services-web-2.6/rest/"
      end

      def service_name
        'EVSS/Dependents'
      end
    end
  end
end
