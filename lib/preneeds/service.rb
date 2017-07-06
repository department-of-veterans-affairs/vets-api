# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/streaming_client'
require 'net/http/post/multipart'

module Preneeds
  class Service < Common::Client::Base
    include Common::Client::StreamingClient
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

    def add_attachment(file, tracking_number, attributes = {})
      attachment = Preneeds::Attachment.with_file(file, attributes.merge(tracking_number: tracking_number))
      soap = savon_client.build_request(:add_attachment, message: attachment.message)

      multipart = build_multipart(soap, attachment)

      http_headers = {}
      multipart.header.fields.each do |field|
        http_headers[field.name] = field.to_s
      end

      response = make_net_http_request(multipart.body.encoded, http_headers)

      if response.is_a? Net::HTTPSuccess
        attachment.message
      else
        # TODO: raise something like BackendServiceException that is serializable?
        {}
      end
    end

    private

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end

    def make_net_http_request(body, headers)
      uri = URI(config.base_path)

      Net::HTTP.start(uri.host, uri.port) do |http|
        begin
          http.use_ssl = (uri.scheme == 'https')
          request = Net::HTTP::Post.new(uri.path, headers)
          request.body = body
          http.request(request)
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError # => e
          # TODO: log_sentry and have a manual strategy in place for resolving this maybe.
          # TODO: trigger breakers
          {}
        end
      end
    end

    def build_multipart(soap, attachment)
      multipart = Mail.new do
        content_type 'multipart/related; type="application/xop+xml"'
        content_transfer_encoding 'chunked'
      end

      soap_part = Mail::Part.new do
        content_type 'text/xml; charset="utf-8"'
        body soap.body
      end

      multipart.add_part(soap_part)

      multipart.attachments[attachment.file.original_filename] = {
        mime_type: 'application/pdf',
        content: Base64.encode64(attachment.file.read),
        content_id: attachment.id,
        content_transfer_encoding: 'binary'
      }

      multipart
    end
  end
end
