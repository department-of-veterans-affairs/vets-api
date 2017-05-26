# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXmlHtmlErrors < Faraday::Response::Middleware
          ERROR_LIST = %w(service_outage generic_xml generic).freeze

          def on_complete(env)
            return if ok_or_json?(env)

            @doc = html?(env) ? Nokogiri::HTML(env.body) : Nokogiri::XML(env.body)

            jsoned_error = ERROR_LIST.each_with_object('') { |error, je| break je if (je = send(error)) }
            jsoned_error['errorCode'] = env.status if jsoned_error['errorCode'].blank?

            env.body = jsoned_error
            env.response_headers['content-type'] = 'application/json'
          end

          private

          attr_reader :doc

          def ok_or_json?(env)
            [1, 2, 3].include?(env.status / 100) || env.response_headers['content-type'] =~ /\bjson/
          end

          def html?(env)
            env.response_headers['content-type'] =~ /html/i
          end

          def service_outage
            fault = doc.xpath('//errormsg:Fault', 'errormsg' => 'http://schemas.xmlsoap.org/soap/envelope/')
            fault_code = fault.at_css('faultcode')
            fault_actor = fault.at_css('faultactor')
            detail = fault.xpath('detail')

            policy_result = detail.xpath('//l7:policyResult', 'l7' => 'http://www.layer7tech.com/ws/policy/fault')
            status = policy_result.present? ? policy_result.attribute('status').inner_text : ''

            return false if [fault, policy_result, fault_code, fault_actor, detail, status].any?(&:blank?)
            {
              'message' => 'MHV Service Outage',
              'developerMessage' => fault_actor.inner_text
            }
          end

          def generic_xml
            error = doc.xpath('Error')
            message = error.at_css('message')
            error_code = error.at_css('errorCode')
            developer_message = error.at_css('developerMessage') # optional

            return false if [error, message, error_code].any?(&:blank?)
            {
              'errorCode' => error_code.inner_text,
              'message' => message.inner_text,
              'developerMessage' => developer_message.inner_text
            }
          end

          def generic
            if doc.html?
              message = doc.title
              developer_message = doc.xpath('html/body').to_html
            else
              developer_message = doc.root.to_html
            end

            {
              'message' => message.blank? ? 'NON-Json error response received' : message,
              'developerMessage' => developer_message
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
