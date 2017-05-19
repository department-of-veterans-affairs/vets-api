# frozen_string_literal: true
# module Common
#   module Client
#     module Middleware
#       module Response
#         class MhvXml < Faraday::Response::Middleware
#           def on_complete(env)
#             return unless xml_error?(env)
#
#             env.response_headers['content-type'] = 'application/json'
#           end
#
#           private
#
#           def xml_error?(env)
#             [4, 5].include?(env.status / 100) &&
#               env.response_headers['content-type'] =~ /\bxml/ &&
#               Nokogiri::XML(env.body).children.length.postive
#           end
#
#           class MhvXmlError
#             SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/'
#             SOAP_NS_PREFIX = 'errormsg'
#
#             L7_NS = 'http://www.layer7tech.com/ws/policy/fault'
#             L7_NS_PREFIX = 'L7'
#
#             ERROR
#
#             attr_accessor :doc, :soapy, :root_node
#
#             def initialize(env)
#               @doc = Nokogiri::XML(env.body)
#               @soapy = doc.to_s =~ Regexp.new(SOAP_NS, true)
#             end
#
#             private
#
#             def root_node
#               @root_mode = soapy? ? doc.xpath()
#             end
#
#             def soapy?
#               @soapy
#             end
#
#             def service_outage?
#               return false unless soapy?
#
#               fault_code = doc.xpath("//errormsg:Fault/faultcode", "errormsg" => SOAP_NS).try(:inner_text)
#               fault_actor = doc.xpath("//errormsg:Fault/faultactor", "errormsg" => SOAP_NS).try(:inner_text)
#               detail =
#             end
#           end
#         end
#       end
#     end
#   end
# end
