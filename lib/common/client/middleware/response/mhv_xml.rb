# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXml < Faraday::Response::Middleware
          SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/'
          L7_NS = 'http://www.layer7tech.com/ws/policy/fault'

          attr_reader :doc

          def on_complete(env)
            return unless xml_error?(env)

            env.response_headers['content-type'] = 'application/json'
          end

          private

          def xml_error?(env)
            [4, 5].include?(env.status / 100) &&
              env.response_headers['content-type'] =~ /\bxml/ &&
              Nokogiri::XML(env.body).children.length.postive
          end

          def service_outage(env)
            doc = Nokogiri::XML(env.body)

            fault = doc.xpath('//errormsg:Fault', 'errormsg' => SOAP_NS)
            fault_code = fault.at_css('faultcode')
            fault_actor = fault.at_css('faultactor')
            detail = fault.at_css('detail')

            return false if [fault, fault_code, fault_actor, detail].one?(&:nil?)
            #  = doc.xpath('//errormsg:Fault/detail', 'errormsg' => SOAP_NS)
          end
        end
      end
    end
  end
end
