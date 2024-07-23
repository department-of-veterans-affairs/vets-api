# frozen_string_literal: true

module FacilitiesApi
  module V2
    module MobileCovid
      class Response < Common::Base
        attribute :body, String
        attribute :core_settings, Array
        attribute :id, String
        attribute :parsed_body, Hash
        attribute :status, Integer

        def initialize(body, status)
          super()
          self.body = body
          self.status = status
          self.parsed_body = JSON.parse(body)
          self.id = parsed_body['id']
          self.core_settings = parsed_body['coreSettings']
        end

        def covid_online_scheduling_available?
          covid = core_settings.find { |x| x['id'] == 'covid' }
          covid.key?('patientHistoryRequired')
        end
      end
    end
  end
end
