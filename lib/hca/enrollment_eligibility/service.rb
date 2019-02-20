# frozen_string_literal: true

module HCA
  module EnrollmentEligibility
    class Service < Common::Client::Base
      configuration HCA::EnrollmentEligibility::Configuration

      def lookup_user(icn)
        response = perform(:post, '', build_lookup_user_xml(icn)).body

        {
          enrollment_status: get_xpath(response, 'env:Envelope/env:Body/getEESummaryResponse/summary/enrollmentDeterminationInfo/enrollmentStatus'),
          application_date: get_xpath(response, 'env:Envelope/env:Body/getEESummaryResponse/summary/enrollmentDeterminationInfo/applicationDate'),
          enrollment_date: get_xpath(response, 'env:Envelope/env:Body/getEESummaryResponse/summary/enrollmentDeterminationInfo/enrollmentDate'),
          preferred_facility: get_xpath(response, 'env:Envelope/env:Body/getEESummaryResponse/summary/demographics/preferredFacility'),
          ineligibility_reason: get_xpath(response, 'env:Envelope/env:Body/getEESummaryResponse/summary/enrollmentDeterminationInfo/ineligibilityFactor/reason')
        }
      end

      private

      def get_xpath(response, xpath)
        node = response.locate(xpath)
        return if node.blank?
        node[0].nodes[0]
      end

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
    end
  end
end
