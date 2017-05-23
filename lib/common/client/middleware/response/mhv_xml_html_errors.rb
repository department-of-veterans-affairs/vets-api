# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXmlHtmlErrors < Faraday::Response::Middleware
          SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/'
          L7_NS = 'http://www.layer7tech.com/ws/policy/fault'
          MHV_INTERNAL_SERVER_ERROR_PATH = '//html/body/font/table/tr/td/font/p/font'

          ERROR_LIST = %w(service_outage mhv_internal_server_error).freeze

          attr_reader :doc

          def on_complete(env)
            return if ok_or_json?(env)

            @doc = html?(env) ? Nokogiri::HTML(env.body) : Nokogiri::XML(env.body)

            json_error = ERROR_LIST.find { |error| send(error) }
            if json_error.present?
              env.response_headers['content-type'] = 'application/json'
              env.body = { 'errorCode' => env.status }.merge(json_error)
            end
          end

          private

          def ok_or_json?(env)
            [1, 2, 3].include?(env.status / 100) || env.response_headers['content-type'] =~ /\bjson/
          end

          def html?(env)
            env.response_headers['content-type'] =~ /\bhtml/
          end

          def service_outage
            fault = doc.xpath('//errormsg:Fault', 'errormsg' => SOAP_NS)
            fault_code = fault.at_css('faultcode')
            fault_actor = fault.at_css('faultactor')
            detail = fault.at_css('detail')

            policy_result = detail.xpath('//l7:', 'l7' => L7_NS)
            status = policyResult['status']

            return false if [fault, policy_result, fault_code, fault_actor, detail, status].one?(&:nil?)

            {
              'message' => 'MHV Service Outage',
              'developerMessage' => fault_actor
            }
          end

          def mhv_internal_server_error
            title = doc.xpath('//html/head/title')
            message = doc.xpath(MHV_INTERNAL_SERVER_ERROR_PATH)

            return false unless title =~ /Internal Server Error/i
            {
              'message' => title,
              'developerMessage' => message
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
