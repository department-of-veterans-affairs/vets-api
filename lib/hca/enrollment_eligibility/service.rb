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

      NAME_MAPPINGS = [
        %i[first givenName],
        %i[middle middleName],
        %i[last familyName],
        %i[suffix suffix]
      ].freeze
      # left API key, right schema key
      INSURANCE_MAPPINGS = {
        'companyName' => 'insuranceName',
        'policyNumber' => 'insurancePolicyNumber',
        'policyHolderName' => 'insurancePolicyHolderName',
        'groupNumber' => 'insuranceGroupCode'
      }.freeze

      MARITAL_STATUSES = %w[
        Married
        Never Married
        Separated
        Widowed
        Divorced
      ].freeze

      MEDICARE = 'Medicare'

      def get_ezr_data(icn)
        response = with_monitoring do
          lookup_user_req(icn)
        end

        income = parse_income(response)
        providers = parse_insurance_providers(response)
        dependents = parse_dependents(response)
        spouse = parse_spouse(response)

        income.merge!(
          convert_insurance_hash(response, providers)
        ).merge!(
          dependents.present? ? { dependents: } : {}
        ).merge!(spouse)
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
          ),
          can_submit_financial_info: !income_year_is_last_year?(response)
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

      def get_marital_status(response)
        marital_status = get_locate_value(
          response,
          "#{XPATH_PREFIX}demographics/maritalStatus"
        )

        return unless MARITAL_STATUSES.include?(marital_status)

        marital_status
      end

      def get_income(response, xpath)
        debugger
        income = {}

        response.locate(xpath)&.each do |i|
          income_type = i.nodes.select { |node| node.value == 'type' }.first&.nodes&.first
          income_amount = i.nodes.select { |node| node.value == 'amount' }.first&.nodes&.first

          case income_type
          when 'Total Employment Income'
            income[:grossIncome] = income_amount
          when 'Net Income from Farm, Ranch, Property, Business'
            income[:netIncome] = income_amount
          when 'All Other Income'
            income[:otherIncome] = income_amount
          end
        end

        income
      end

      def parse_income(response)
        income_xpath = "#{XPATH_PREFIX}financialsInfo/financialStatement/"

        Common::HashHelpers.deep_compact(
          {
            veteranIncome: get_income(
              response,
              "#{income_xpath}incomes/income"
            ),
            spouseIncome: get_income(
              response,
              "#{income_xpath}spouseFinancialsList/spouseFinancials/incomes/income"
            )
          }
        )
      end


      # rubocop:disable Metrics/MethodLength
      def parse_spouse(response)
        spouse_financials_xpath =
          "#{XPATH_PREFIX}financialsInfo/financialStatement/spouseFinancialsList/spouseFinancials/"

        Common::HashHelpers.deep_compact(
          {
            spouseFullName: lambda do
              return_val = {}

              NAME_MAPPINGS.each do |mapping|
                return_val[mapping[0]] = get_locate_value(
                  response,
                  "#{spouse_financials_xpath}spouse/#{mapping[1]}"
                )
              end

              return if return_val.compact.blank?

              return_val
            end.call,
            maritalStatus: get_marital_status(response),
            dateOfMarriage: get_locate_value_date(
              response,
              "#{spouse_financials_xpath}spouse/startDate"
            ),
            cohabitedLastYear: get_locate_value_bool(
              response,
              "#{spouse_financials_xpath}livedWithPatient"
            ),
            spouseDateOfBirth: get_locate_value_date(
              response,
              "#{spouse_financials_xpath}spouse/dob"
            ),
            spouseSocialSecurityNumber: get_locate_value(
              response,
              "#{spouse_financials_xpath}spouse/ssns/ssn/ssnText"
            ),
            spouseIncomeYear: get_locate_value(
              response,
              "#{spouse_financials_xpath}incomeYear"
            )
          }
        )
      end
      # rubocop:enable Metrics/MethodLength

      def parse_dependents(response)
        dependents = []

        response.locate(
          "#{XPATH_PREFIX}financialsInfo/financialStatement/dependentFinancialsList"
        )[0]&.nodes&.each do |dep_node|
          dependent = {
            fullName: {},
            socialSecurityNumber: get_locate_value(dep_node, 'dependentInfo/ssns/ssn/ssnText'),
            becameDependent: get_locate_value_date(dep_node, 'dependentInfo/startDate'),
            dependentRelation: get_locate_value(dep_node, 'dependentInfo/relationship').downcase.upcase_first,
            disabledBefore18: get_locate_value_bool(dep_node, 'incapableOfSelfSupport'),
            attendedSchoolLastYear: get_locate_value_bool(dep_node, 'attendedSchool'),
            cohabitedLastYear: get_locate_value_bool(dep_node, 'livedWithPatient'),
            dateOfBirth: get_locate_value_date(dep_node, 'dependentInfo/dob')
          }

          NAME_MAPPINGS.each do |mapping|
            dependent[:fullName][mapping[0]] = get_locate_value(dep_node, "dependentInfo/#{mapping[1]}")
          end

          dependents << Common::HashHelpers.deep_compact(dependent)
        end

        dependents
      end

      def get_locate_value_date(node, key)
        parse_es_date(get_locate_value(node, key))
      end

      def get_locate_value_bool(node, key)
        ActiveModel::Type::Boolean.new.cast(get_locate_value(node, key))
      end

      def get_locate_value(node, key)
        res = node.locate(key)[0]
        return if res.nil?

        res.nodes[0]
      end

      def parse_insurance_providers(response)
        providers = []

        response.locate("#{XPATH_PREFIX}insuranceList")[0]&.nodes&.each do |insurance_node|
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

        return_val.delete(:providers) if return_val[:providers].blank?

        return_val
      end

      def parse_es_date(date_str)
        return if date_str.blank?

        Date.parse(date_str).to_s
      rescue Date::Error => e
        log_exception_to_sentry(e)
        PersonalInformationLog.create!(
          data: date_str,
          error_class: 'Form1010Ezr DateError'
        )

        nil
      end

      def part_a_effective_date(response)
        get_locate_value_date(response, "#{XPATH_PREFIX}insuranceList/insurance/partAEffectiveDate")
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

      def income_year_is_last_year?(response)
        income_year = get_xpath(
          response,
          "#{XPATH_PREFIX}financialsInfo/incomeTest/incomeYear"
        )

        income_year == (DateTime.now.utc.year - 1).to_s
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
