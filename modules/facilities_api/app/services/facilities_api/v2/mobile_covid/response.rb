# frozen_string_literal: true

require 'vets/model'

module FacilitiesApi
  module V2
    module MobileCovid
      class Response
        include Vets::Model

        attribute :body, String
        attribute :core_settings, Hash, array: true
        attribute :id, String
        attribute :parsed_body, Hash
        attribute :status, Integer

        def initialize(body, status)
          super()

          @body = body
          @status = status
          @parsed_body = JSON.parse(body)
          @id = parsed_body['id']
          @core_settings = parsed_body['coreSettings']
        end

        def covid_online_scheduling_available?
          covid = core_settings.find { |x| x['id'] == 'covid' }
          covid.key?('patientHistoryRequired')
        end
      end
    end
  end
end
