# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXmlHtmlErrors < Faraday::Response::Middleware
          include SentryLogging

          ERROR_LIST = %w(service_outage generic_xml generic).freeze

          def on_complete(env)
            return unless error_and_xml_or_html?(env)

            @doc = html?(env) ? Nokogiri::HTML(env.body) : Nokogiri::XML(env.body)

            jsoned_error = ERROR_LIST.each_with_object('') { |error, je| break je if (je = send(error)) }
            # NOTE: errorCode should not be set to env.status because that could inadvertedly map to a known error
            jsoned_error['errorCode'] = 'MHV-UNKNOWN-ERROR' if jsoned_error['errorCode'].blank?

            env.body = jsoned_error
            env.response_headers['content-type'] = 'application/json'
          rescue ArgumentError => exception
            log_exception_to_sentry(exception)
            extra_context = { original_status: env.status, original_body: env.body }
            log_message_to_sentry('Could not parse XML/HTML', :warning, extra_context)
            env.body = {
              'errorCode' => 'MHV-UNKNOWN-ERROR',
              'message' => 'Received an error response that could not be processed',
              'developerMessage' => 'Check Logs for: Could not parse XML/HTML'
            }
            env.response_headers['content-type'] = 'application/json'
          ensure
            env
          end

          private

          attr_reader :doc

          def error_and_xml_or_html?(env)
            [4, 5].include?(env.status / 100) &&
              (env.response_headers['content-type'] =~ /\bxml/ || env.response_headers['content-type'] =~ /\bhtml/)
          end

          def html?(env)
            env.response_headers['content-type'] =~ /html/i
          end

          def verify?(nodes, values = {})
            nodes.none?(&:blank?) && values.all? { |v1, v2| v1.casecmp(v2.to_s) }
          end

          def service_outage
            fault = doc.xpath('//errormsg:Fault', 'errormsg' => 'http://schemas.xmlsoap.org/soap/envelope/')
            fault_actor = fault.at_css('faultactor')
            detail = fault.xpath('detail')
            policy_result = detail.xpath('//l7:policyResult', 'l7' => 'http://www.layer7tech.com/ws/policy/fault')

            fault_code = fault.at_css('faultcode').try(:inner_text)
            fault_string = fault.at_css('faultString').try(:inner_text)
            status = policy_result.present? ? policy_result.attribute('status').inner_text : ''

            return false unless verify?(
              [fault, fault_actor, detail, policy_result],
              'assertion falsified' => status, 'soapenv:server' => fault_code, 'policy falsified' => fault_string
            )

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

            return false unless verify?([error, message, error_code])
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

            log_message_to_sentry(developer_message, :error)

            {
              'message' => message.blank? ? 'Received an error response that could not be processed' : message
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
