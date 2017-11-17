# frozen_string_literal: true
require 'common/client/base'

module Preneeds
  class Service < Common::Client::Base
    configuration Preneeds::Configuration

    STARTING_CID = '<soap-request-body@soap>'

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

      body_and_headers = build_body_and_headers(soap, burial_form)

      json = perform(:post, '', body_and_headers[:body], body_and_headers[:headers]).body

      json = json[:data].merge('tracking_number' => tracking_number)

      ReceiveApplication.new(json)
    end

    private

    def build_body_and_headers(soap, burial_form)
      headers = {}

      body =
        if burial_form.has_attachments
          multipart = build_multipart(soap, burial_form.attachments)

          multipart.header.fields.each do |field|
            headers[field.name] = field.to_s
          end

          multipart.body.encoded
        else
          soap.body
        end

      headers["Content-Type"] = "multipart/related; " \
        "boundary=\"#{multipart.boundary}\"; " \
        "type=\"text/xml\"; start=\"#{STARTING_CID}\""

      {
        body: body,
        headers: headers
      }
    end

    def build_multipart(soap, attachments)
      multipart = Mail.new

      soap_part = Mail::Part.new do
        content_type 'text/xml; charset="utf-8"'
        body soap.body
        content_id STARTING_CID
      end

      multipart.add_part(soap_part)

      attachments.each do |attachment|
        file = attachment.file

        part = Mail::Part.new do
          content_type(file.content_type)
          body(file.read)
          content_id("<#{attachment.data_handler}>")
        end

        multipart.add_part(part)
      end

      multipart
    end

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end
  end
end
