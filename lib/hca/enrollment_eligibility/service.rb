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

      # left API key, right schema key
      INSURANCE_MAPPINGS = {
        'companyName' => 'insuranceName',
        'policyNumber' => 'insurancePolicyNumber',
        'policyHolderName' => 'insurancePolicyHolderName',
        'groupNumber' => 'insuranceGroupCode'
      }.freeze

      MEDICARE = 'Medicare'

      def get_ezr_data(icn)
        response = with_monitoring do
          lookup_user_req(icn)
        end

        providers = parse_insurance_providers(response)

        OpenStruct.new(convert_insurance_hash(response, providers))
      end

      # rubocop:disable Metrics/MethodLength
      def lookup_user(icn)
        response = with_monitoring do
          lookup_user_req(icn)
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

      def convert_insurance_hash(response, providers)
        strip_medicare(providers).merge(
          {
            isEnrolledMedicarePartA: get_xpath(
              response,
              "#{XPATH_PREFIX}insuranceList/insurance/enrolledInPartA"
            ) == 'true',
            medicarePartAEffectiveDate: part_a_effective_date(response),
            isMedicaidEligible: ActiveModel::Type::Boolean.new.cast(
              get_xpath(
                response,
                "#{XPATH_PREFIX}enrollmentDeterminationInfo/eligibleForMedicaid"
              )
            )
          }
        )
      end

      def parse_insurance_providers(response)
        providers = []

        response.locate("#{XPATH_PREFIX}insuranceList")[0].nodes.each do |insurance_node|
          insurance = {}

          insurance_node.nodes.each do |insurance_inner|
            INSURANCE_MAPPINGS.each do |k, v|
              insurance[v] = insurance_inner.nodes[0] if insurance_inner.value == k
            end
          end

          providers << insurance
        end

        providers
      end

      def strip_medicare(providers)
        return_val = {
          providers: [],
          medicareClaimNumber: nil
        }

        providers.each do |provider|
          if provider['insuranceName'] == MEDICARE
            return_val[:medicareClaimNumber] = provider['insurancePolicyNumber']
          else
            return_val[:providers] << provider
          end
        end

        return_val
      end

      def part_a_effective_date(response)
        res = get_xpath(
          response,
          "#{XPATH_PREFIX}insuranceList/insurance/partAEffectiveDate"
        )
        return if res.blank?

        Date.parse(res).to_s
      end

      def lookup_user_req(icn)
        perform(:post, '', build_lookup_user_xml(icn)).body
      end

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
