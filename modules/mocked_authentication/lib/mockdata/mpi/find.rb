# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'openssl'

module MockedAuthentication
  module Mockdata
    module MPI
      class Find
        CONTENT_TYPE = 'text/xml;charset=UTF-8'
        SOAPACTION = 'PRPA_IN201305UV02'
        USER_AGENT = 'Vets.gov Agent'
        CONNECTION = 'close'
        TEMPLATE_PATH = 'config/mpi_schema/mpi_find_person_icn_template.xml'
        MPI_ERROR_CODE = 'INTERR'

        attr_reader :icn

        def initialize(icn:)
          @icn = icn
        end

        def perform
          response_yml
        end

        private

        def mpi_response
          @mpi_response ||= begin
            uri = URI.parse(IdentitySettings.mvi.url)
            request = Net::HTTP::Post.new(uri)
            request.content_type = CONTENT_TYPE
            request['Connection'] = CONNECTION
            request['User-Agent'] = USER_AGENT
            request['Soapaction'] = SOAPACTION
            template = Liquid::Template.parse(Rails.root.join(TEMPLATE_PATH).read)
            xml = template.render!('icn' => icn)
            request.body = xml
            req_options = { use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_PEER }
            Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
          end
        end

        def response_yml
          raise Common::Exceptions::RecordNotFound, 'User not found' if mpi_response&.body&.include?(MPI_ERROR_CODE)

          @response_yml ||= {
            method: :post,
            body: Nokogiri::XML(mpi_response.body).root.to_xml,
            headers: {
              connection: 'close',
              date: Time.zone.now.strftime('%a, %d %b %Y %H:%M:%S %Z'),
              'content-type' => 'text/xml'
            },
            status: 200
          }.to_yaml
        end
      end
    end
  end
end
