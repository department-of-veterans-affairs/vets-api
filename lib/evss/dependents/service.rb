# frozen_string_literal: true

module EVSS
  module Dependents
    class Service < EVSS::Service
      configuration EVSS::Dependents::Configuration
      def retrieve
        perform(:get, 'load/retrieve')
      end
    end
  end
end
