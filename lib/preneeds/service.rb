# frozen_string_literal: true
require 'common/client/base'

module Preneeds
  class Service < Common::Client::Base
    configuration Preneeds::Configuration

    def get_attachment_types
      soap = savon_client.build_request(:get_attachment_types, message: {})
      data = perform(:post, '', soap.body).body

      Common::Collection.new(AttachmentType, data)
    end

    def get_branches_of_service
      soap = savon_client.build_request(:get_branches_of_service, message: {})
      data = perform(:post, '', soap.body).body

      Common::Collection.new(BranchesOfService, data)
    end

    def get_cemeteries
      soap = savon_client.build_request(:get_cemeteries, message: {})
      data = perform(:post, '', soap.body).body

      Common::Collection.new(Cemetery, data)
    end

    def get_discharge_types
      soap = savon_client.build_request(:get_discharge_types, message: {})
      data = perform(:post, '', soap.body).body

      Common::Collection.new(DischargeType, data)
    end

    def get_military_rank_for_branch_of_service(params)
      soap = savon_client.build_request(:get_military_rank_for_branch_of_service, message: params)
      data = perform(:post, '', soap.body).body

      Common::Collection.new(MilitaryRank, data)
    end

    def get_states
      soap = savon_client.build_request(:get_states, message: {})
      data = perform(:post, '', soap.body).body

      Common::Collection.new(State, data)
    end

    def add_attachment(file)
      attachment = Preneeds::Attachment.with_file(file)
      soap = savon_client.build_request(:add_attachment, message: attachment.message)

      data = perform(:post, '', soap.body).body
    end

    private

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end
  end
end
