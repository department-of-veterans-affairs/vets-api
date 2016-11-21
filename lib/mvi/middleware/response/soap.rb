# frozen_string_literal: true
require 'mvi/errors/errors'

module MVI
  module Middleware
    module Response
      class Soap < Faraday::Response::Middleware
        def on_complete(env)
          case env.status
          when 200
            doc = Ox.parse(ensure_xml_prolog(env.body))
            raise MVI::Errors::HTTPError.new('MVI internal server error', 500) if doc_includes_error(doc)
            env.body = doc
          else
            Rails.logger.error env.body
            raise MVI::Errors::HTTPError.new('MVI HTTP call failed', env.status)
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
          Rails.logger.error "MVI fault code: #{fault_code.nodes.first}" if fault_code
          Rails.logger.error "MVI fault string: #{fault_string.nodes.first}" if fault_string
          true
        end
      end
    end
  end
end
