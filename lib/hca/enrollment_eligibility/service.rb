# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module HCA
  module EnrollmentEligibility
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      XPATH_PREFIX = 'env:Envelope/env:Body/getEESummaryResponse/summary/'
      configuration HCA::EnrollmentEligibility::Configuration

      STATSD_KEY_PREFIX = 'api.hca_ee'

      # rubocop:disable Metrics/MethodLength
      def lookup_user(icn)
        response = with_monitoring do
          perform(:post, '', build_lookup_user_xml(icn)).body
        end

        {
          enrollment_status: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/enrollmentStatus"
          ),
          application_date: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/applicationDate"
          ),
          enrollment_date: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/enrollmentDate"
          ),
          preferred_facility: get_xpath(
            response,
            "#{XPATH_PREFIX}demographics/preferredFacility"
          ),
          ineligibility_reason: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/ineligibilityFactor/reason"
          ),
          effective_date: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/effectiveDate"
          ),
          primary_eligibility: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/primaryEligibility/type"
          ),
          veteran: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/veteran"
          ),
          priority_group: get_xpath(
            response,
            "#{XPATH_PREFIX}enrollmentDeterminationInfo/priorityGroup"
          )
        }
      end
      # rubocop:enable Metrics/MethodLength

      private

      def get_xpath(response, xpath)
        node = response.locate(xpath)
        return if node.blank?

        node[0].nodes[0]
      end

      # rubocop:disable Metrics/MethodLength
      def build_lookup_user_xml(icn)
        Nokogiri::XML::Builder.new do |xml|
          xml.public_send(
            'SOAP-ENV:Envelope',
            'xmlns:SOAP-ENV' => 'http://schemas.xmlsoap.org/soap/envelope/',
            'xmlns:sch' => 'http://jaxws.webservices.esr.med.va.gov/schemas'
          ) do
            xml.public_send('SOAP-ENV:Header') do
              xml.public_send(
                'wsse:Security',
                'SOAP-ENV:mustUnderstand' => '1',
                'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
              ) do
                xml.public_send(
                  'wsse:UsernameToken',
                  'wsu:Id' => 'XWSSGID-1281117217796-43574433',
                  'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
                ) do
                  xml.public_send('wsse:Username', Settings.hca.ee.user)
                  xml.public_send(
                    'wsse:Password',
                    Settings.hca.ee.pass,
                    'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText'
                  )
                end
              end
            end

            xml.public_send('SOAP-ENV:Body') do
              xml.public_send('sch:getEESummaryRequest') do
                xml.public_send('sch:key', icn)
                xml.public_send('sch:requestName', 'HCAData')
              end
            end
          end
        end.to_xml
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
