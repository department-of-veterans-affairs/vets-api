# frozen_string_literal: true
require 'soap/errors'

module SOAP
  module Middleware
    module Response
      class Parse < Faraday::Response::Middleware
        def initialize(app, options = {})
          super(app)
          @service_name = options[:name] || 'SOAP'
        end

        def on_complete(env)
          case env.status
          when 200
            doc = Ox.parse(ensure_xml_prolog(env.body))
            raise SOAP::Errors::HTTPError.new("#{@service_name} internal server error", 500) if doc_includes_error(doc)
            env.body = doc
          else
            Rails.logger.error env.body
            raise SOAP::Errors::HTTPError.new("#{@service_name} HTTP call failed", env.status)
          end
        end

        private

        def ensure_xml_prolog(xml)
          xml = xml.dup.prepend('<?xml version="1.0" encoding="UTF-8"?>') unless xml =~ /^<\?xml/
          xml
        end

        def doc_includes_error(doc)
          fault_element = doc.locate('env:Envelope/env:Body/env:Fault').first
          return false unless fault_element
          fault_code = fault_element.locate('faultcode').first
          fault_string = fault_element.locate('faultstring').first
          Rails.logger.error "#{@service_name} fault code: #{fault_code.nodes.first}" if fault_code
          Rails.logger.error "#{@service_name} fault string: #{fault_string.nodes.first}" if fault_string
          true
        end
      end
    end
  end
end
