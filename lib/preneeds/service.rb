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

    def receive_pre_need_application(burial_form)
      tracking_number = burial_form.tracking_number

      soap = savon_client.build_request(:receive_pre_need_application, message: { pre_need_request: burial_form.as_eoas })

      multipart = build_multipart(soap, burial_form.attachments)

      json = perform(:post, '', soap.body).body

      json = json[:data].merge('tracking_number' => tracking_number)

      ReceiveApplication.new(json)
    end

    private

    def build_multipart(soap, attachments)
      multipart = Mail.new do
        content_type 'multipart/related; type="application/xop+xml"'
        content_transfer_encoding 'chunked'
      end

      soap_part = Mail::Part.new do
        content_type 'text/xml; charset="utf-8"'
        body soap.body
      end

      multipart.add_part(soap_part)

      attachments.each do |attachment|
        file = attachment.file

        multipart.attachments[attachment.guid] = {
          mime_type: file.content_type,
          content: Base64.encode64(file.read),
          content_id: attachment.guid,
          content_transfer_encoding: 'binary'
        }
      end

      multipart
    end

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end
  end
end
