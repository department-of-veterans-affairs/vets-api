# frozen_string_literal: true
require 'common/client/base'

module Preneeds
  class Service < Common::Client::Base
    configuration Preneeds::Configuration

    def get_attachment_types
      soap = savon_client.build_request(:get_attachment_types, message: {})
      json = perform(:post, '', soap.body).body

      Common::Collection.new(AttachmentType, json)
    end

    def get_branches_of_service
      soap = savon_client.build_request(:get_branches_of_service, message: {})
      json = perform(:post, '', soap.body).body

      Common::Collection.new(BranchesOfService, json)
    end

    def get_cemeteries
      soap = savon_client.build_request(:get_cemeteries, message: {})
      json = perform(:post, '', soap.body).body

      Common::Collection.new(Cemetery, json)
    end

    def get_discharge_types
      soap = savon_client.build_request(:get_discharge_types, message: {})
      json = perform(:post, '', soap.body).body

      Common::Collection.new(DischargeType, json)
    end

    def get_military_rank_for_branch_of_service(params)
      soap = savon_client.build_request(:get_military_rank_for_branch_of_service, message: params)
      json = perform(:post, '', soap.body).body

      Common::Collection.new(MilitaryRank, json)
    end

    def get_states
      soap = savon_client.build_request(:get_states, message: {})
      json = perform(:post, '', soap.body).body

      Common::Collection.new(State, json)
    end

    private

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end
  end
end
