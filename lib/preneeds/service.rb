# frozen_string_literal: true

require 'common/client/base'

module Preneeds
  # Proxy Service for the EOAS (Eligibility Office Automation System) Service's PreNeed Applications endpoints.
  # Requests are SOAP format, and the request bodies are built using the `Savon` gem,
  # The `Mail` gem is used to generate attachments for the #receive_pre_need_application method.
  # The actual submission of requests is facilitated using methods defined in the {Common::Client::Base} parent class.
  #
  class Service < Common::Client::Base
    # Prefix string for StatsD monitoring
    STATSD_KEY_PREFIX = 'api.preneeds'

    # Specifies configuration to be used by this service.
    #
    configuration Preneeds::Configuration
    include Common::Client::Concerns::Monitoring

    # Used in building SOAP request
    STARTING_CID = '<soap-request-body@soap>'

    # POST to retrieve military cemeteries
    #
    # @return [Common::Collection<Preneeds::Cemetery>] collection of military cemeteries
    #
    def get_cemeteries
      soap = savon_client.build_request(:get_cemeteries, message: {})
      json = with_monitoring { perform(:post, '', soap.body).body }

      Common::Collection.new(Cemetery, **json)
    end

    # POST to submit a {Preneeds::BurialForm}
    #
    # @param burial_form [Preneeds::BurialForm] a valid BurialForm object
    # @return [Preneeds::ReceiveApplication] object with details of the BurialForm submission response
    #
    def receive_pre_need_application(burial_form)
      tracking_number = burial_form.tracking_number
      soap = savon_client.build_request(
        :receive_pre_need_application,
        message: {
          pre_need_request: burial_form.as_eoas
        }
      )

      body_and_headers = build_body_and_headers(soap, burial_form)

      json = with_monitoring { perform(:post, '', body_and_headers[:body], body_and_headers[:headers]).body }
      Raven.extra_context(response: json)

      json = json[:data].merge('tracking_number' => tracking_number)

      ReceiveApplication.new(json)
    end

    private

    # Builds SOAP body and headers for #receive_pre_need_application
    #
    # @param soap [HTTPI::Request] SOAP request object built by `Savon` gem
    # @param burial_form [Preneeds::BurialForm] the {Preneeds::BurialForm} object
    #
    # @return [Hash] hash containing the body and headers for the #receive_pre_need_application request
    #
    def build_body_and_headers(soap, burial_form)
      headers = {}

      body =
        if burial_form.has_attachments
          multipart = build_multipart(soap, burial_form.attachments)

          multipart.header.fields.each do |field|
            headers[field.name] = field.to_s
          end

          headers['Content-Type'] = 'multipart/related; ' \
                                    "boundary=\"#{multipart.boundary}\"; " \
                                    "type=\"application/xop+xml\"; start=\"#{STARTING_CID}\"; " \
                                    'start-info="text/xml"'

          multipart.body.encoded
        else
          soap.body
        end

      {
        body: body,
        headers: headers
      }
    end

    # Builds SOAP attachments for #receive_pre_need_application
    #
    # @param soap [HTTPI::Request] SOAP request object built by `Savon` gem
    # @param attachments [Array<Preneeds::Attachment>] the attachments from the Preneeds::BurialForm object
    #
    # @return [Mail::Message] object with burial form attachments
    #
    def build_multipart(soap, attachments)
      multipart = Mail.new

      soap_part = Mail::Part.new do
        content_type 'application/xop+xml; charset=UTF-8; type="text/xml"'
        body soap.body
        content_id STARTING_CID
      end

      multipart.add_part(soap_part)

      attachments.each do |attachment|
        file = attachment.file

        multipart.add_file(
          filename: attachment.name,
          content: file.read
        )

        part = multipart.parts.last
        part.content_id("<#{attachment.data_handler}>")
        part.content_type(file.content_type)
      end

      multipart
    end

    # Savon client for building SOAP request; initialized with PreNeeds WSDL
    #
    # @return [Savon::Client] Savon client
    #
    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end
  end
end
