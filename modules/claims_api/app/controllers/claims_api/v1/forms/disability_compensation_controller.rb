# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'evss/disability_compensation_form/service_exception'
require 'evss/error_middleware'
require 'evss/reference_data/service'
require 'common/exceptions'
require 'jsonapi/parser'

module ClaimsApi
  module V1
    module Forms
      class DisabilityCompensationController < ClaimsApi::V1::Forms::Base
        include ClaimsApi::PoaVerification
        include ClaimsApi::DocumentValidations

        FORM_NUMBER = '526'
        STATSD_VALIDATION_FAIL_KEY = 'api.claims_api.526.validation_fail'
        STATSD_VALIDATION_FAIL_TYPE_KEY = 'api.claims_api.526.validation_fail_type'

        before_action except: %i[schema] do
          permit_scopes %w[claim.write]
        end
        skip_before_action :validate_json_format, only: %i[upload_supporting_documents]
        before_action :verify_power_of_attorney!, if: :header_request?
        skip_before_action :validate_veteran_identifiers, only: %i[submit_form_526 validate_form_526]

        # POST to submit disability claim.
        #
        # @return [JSON] Record in pending state
        def submit_form_526 # rubocop:disable Metrics/MethodLength
          validate_json_schema
          validate_form_526_submission_values!
          validate_veteran_identifiers(require_birls: true)
          validate_initial_claim

          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            flashes: flashes,
            special_issues: special_issues_per_disability,
            source: source_name
          )
          unless auto_claim.id
            existing_auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5, source: source_name)
            auto_claim = existing_auto_claim if existing_auto_claim.present?
          end

          if auto_claim.errors.present?
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: auto_claim.errors.messages.to_s)
          end

          unless form_attributes['autoCestPDFGenerationDisabled'] == true
            ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)
          end

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        # PUT to upload a wet-signed 526 form.
        # Required if first ever claim for Veteran.
        #
        # @return [JSON] Claim record
        def upload_form_526
          validate_documents_content_type
          validate_documents_page_size

          pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id])

          if pending_claim && (pending_claim.form_data['autoCestPDFGenerationDisabled'] == true)
            pending_claim.set_file_data!(documents.first, params[:doc_type])
            pending_claim.save!

            ClaimsApi::ClaimEstablisher.perform_async(pending_claim.id)
            ClaimsApi::ClaimUploader.perform_async(pending_claim.id)

            render json: pending_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
          elsif pending_claim && (pending_claim.form_data['autoCestPDFGenerationDisabled'] == false)
            message = <<-MESSAGE
              Claim submission requires that the "autoCestPDFGenerationDisabled" field
              must be set to "true" in order to allow a 526 PDF to be uploaded
            MESSAGE
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
          else
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
          end
        end

        # POST to upload additional documents to support relevent disability compensation claim.
        #
        # @return [JSON] Claim record
        def upload_supporting_documents
          validate_documents_content_type
          validate_documents_page_size

          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless claim

          documents.each do |document|
            claim_document = claim.supporting_documents.build
            claim_document.set_file_data!(document, params[:doc_type], params[:description])
            claim_document.save!
            ClaimsApi::ClaimUploader.perform_async(claim_document.id)
          end

          render json: claim, serializer: ClaimsApi::ClaimDetailSerializer, uuid: claim.id
        end

        # POST to validate 526 submission payload.
        #
        # @return [JSON] Success if valid, error messages if invalid.
        # rubocop:disable Metrics/MethodLength
        def validate_form_526
          add_deprecation_headers_to_response(response: response, link: ClaimsApi::EndpointDeprecation::V1_DEV_DOCS)
          validate_json_schema
          validate_veteran_identifiers(require_birls: true)
          validate_initial_claim

          service = EVSS::DisabilityCompensationForm::Service.new(auth_headers)
          auto_claim = ClaimsApi::AutoEstablishedClaim.new(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes
          )
          service.validate_form526(auto_claim.to_internal)
          render json: valid_526_response
        rescue ::EVSS::DisabilityCompensationForm::ServiceException, EVSS::ErrorMiddleware::EVSSError => e
          error_details = e.is_a?(EVSS::ErrorMiddleware::EVSSError) ? e.details : e.messages
          track_526_validation_errors(error_details)
          raise ::Common::Exceptions::UnprocessableEntity.new(errors: format_526_errors(error_details))
        rescue ::Common::Exceptions::GatewayTimeout,
               ::Timeout::Error,
               ::Faraday::TimeoutError,
               Breakers::OutageException => e
          req = { auth: auth_headers, form: form_attributes, source: source_name, auto_claim: auto_claim.as_json }
          PersonalInformationLog.create(
            error_class: "validate_form_526 #{e.class.name}", data: { request: req, error: e.try(:as_json) || e }
          )
          raise e
        end
        # rubocop:enable Metrics/MethodLength

        private

        #
        # Any custom 526 submission validations above and beyond json schema validation
        #
        def validate_form_526_submission_values!
          validate_form_526_submission_claim_date!
          validate_form_526_application_expiration_date!
          validate_form_526_claimant_certification!
          validate_form_526_location_codes!
          validate_form_526_service_information_confinements!
          validate_form_526_veteran_homelessness!
          validate_form_526_service_pay!
          validate_form_526_title10_activation_date!
        end

        def validate_form_526_title10_activation_date!
          title10_activation_date = form_attributes.dig('serviceInformation',
                                                        'reservesNationalGuardService',
                                                        'title10Activation',
                                                        'title10ActivationDate')
          return if title10_activation_date.blank?

          end_dates = form_attributes['serviceInformation']['servicePeriods'].map do |service_period|
            Date.parse(service_period['activeDutyEndDate'])
          end

          return if Date.parse(title10_activation_date) > end_dates.min &&
                    Date.parse(title10_activation_date) <= Time.zone.now

          raise ::Common::Exceptions::InvalidFieldValue.new('title10ActivationDate', title10_activation_date)
        end

        def validate_form_526_submission_claim_date!
          return if form_attributes['claimDate'].blank?
          return if Date.parse(form_attributes['claimDate']) <= Time.zone.today

          raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
        end

        def validate_form_526_application_expiration_date!
          return if Date.parse(form_attributes['applicationExpirationDate']) >= Time.zone.today

          raise ::Common::Exceptions::InvalidFieldValue.new('applicationExpirationDate',
                                                            form_attributes['applicationExpirationDate'])
        end

        def validate_form_526_claimant_certification!
          return unless form_attributes['claimantCertification'] == false

          raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                            form_attributes['claimantCertification'])
        end

        def validate_form_526_location_codes!
          locations_response = EVSS::ReferenceData::Service.new(@current_user).get_separation_locations
          separation_locations = locations_response.separation_locations
          form_attributes['serviceInformation']['servicePeriods'].each do |service_period|
            next if Date.parse(service_period['activeDutyEndDate']) <= Time.zone.today
            next if separation_locations.any? do |location|
                      location['code'] == service_period['separationLocationCode']
                    end

            raise ::Common::Exceptions::InvalidFieldValue.new('separationLocationCode',
                                                              form_attributes['separationLocationCode'])
          end
        end

        def validate_form_526_service_information_confinements!
          confinements = form_attributes['serviceInformation']['confinements']
          service_periods = form_attributes['serviceInformation']['servicePeriods']

          return if confinements.nil?

          return if confinements_within_service_periods?(confinements,
                                                         service_periods) && confinements_dont_overlap?(confinements)

          raise ::Common::Exceptions::InvalidFieldValue.new('confinements', confinements)
        end

        def confinements_within_service_periods?(confinements, service_periods)
          confinements.each do |confinement|
            next if service_periods.any? do |service_period|
              active_duty_start = Date.parse(service_period['activeDutyBeginDate'])
              active_duty_end = Date.parse(service_period['activeDutyEndDate'])
              time_range = active_duty_start..active_duty_end

              time_range.cover?(Date.parse(confinement['confinementBeginDate'])) &&
              time_range.cover?(Date.parse(confinement['confinementEndDate']))
            end

            return false
          end

          true
        end

        def confinements_dont_overlap?(confinements)
          return true if confinements.length < 2

          confinements.combination(2) do |combo|
            range1 = Date.parse(combo[0]['confinementBeginDate'])..Date.parse(combo[0]['confinementEndDate'])
            range2 = Date.parse(combo[1]['confinementBeginDate'])..Date.parse(combo[1]['confinementEndDate'])
            return false if range1.overlaps?(range2)
          end

          true
        end

        def validate_form_526_veteran_homelessness!
          if too_many_homelessness_attributes_provided? || unnecessary_homelessness_point_of_contact_provided?
            raise ::Common::Exceptions::InvalidFieldValue.new(
              'homelessness',
              form_attributes['veteran']['homelessness']
            )
          end
        end

        def validate_form_526_service_pay!
          receiving_attr    = form_attributes.dig('servicePay', 'militaryRetiredPay', 'receiving')
          will_receive_attr = form_attributes.dig('servicePay', 'militaryRetiredPay', 'willReceiveInFuture')

          return if receiving_attr.nil? || will_receive_attr.nil?
          return unless receiving_attr == will_receive_attr

          # EVSS does not allow both attributes to be the same value (unless that value is nil)
          raise ::Common::Exceptions::InvalidFieldValue.new(
            'servicePay.militaryRetiredPay',
            form_attributes['servicePay']['militaryRetiredPay']
          )
        end

        def too_many_homelessness_attributes_provided?
          currently_homeless_attr = form_attributes.dig('veteran', 'homelessness', 'currentlyHomeless')
          homelessness_risk_attr  = form_attributes.dig('veteran', 'homelessness', 'homelessnessRisk')

          # EVSS does not allow both attributes to be provided at the same time
          currently_homeless_attr.present? && homelessness_risk_attr.present?
        end

        def unnecessary_homelessness_point_of_contact_provided?
          currently_homeless_attr = form_attributes.dig('veteran', 'homelessness', 'currentlyHomeless')
          homelessness_risk_attr  = form_attributes.dig('veteran', 'homelessness', 'homelessnessRisk')
          homelessness_poc_attr   = form_attributes.dig('veteran', 'homelessness', 'pointOfContact')

          # EVSS does not allow passing a 'pointOfContact' if neither homelessness attribute is provided
          currently_homeless_attr.blank? && homelessness_risk_attr.blank? && homelessness_poc_attr.present?
        end

        def flashes
          initial_flashes = form_attributes.dig('veteran', 'flashes') || []
          homelessness = form_attributes.dig('veteran', 'homelessness')
          is_terminally_ill = form_attributes.dig('veteran', 'isTerminallyIll')

          initial_flashes.push('Homeless') if homelessness.present?
          initial_flashes.push('Terminally Ill') if is_terminally_ill.present? && is_terminally_ill

          initial_flashes.present? ? initial_flashes.uniq : []
        end

        def special_issues_per_disability
          (form_attributes['disabilities'] || []).map { |disability| special_issues_for_disability(disability) }
        end

        def special_issues_for_disability(disability)
          primary_special_issues = disability['specialIssues'] || []
          secondary_special_issues = []
          (disability['secondaryDisabilities'] || []).each do |secondary_disability|
            secondary_special_issues += (secondary_disability['specialIssues'] || [])
          end
          special_issues = primary_special_issues + secondary_special_issues

          mapper = ClaimsApi::SpecialIssueMappers::Bgs.new
          {
            code: disability['diagnosticCode'],
            name: disability['name'],
            special_issues: special_issues.map { |special_issue| mapper.code_from_name!(special_issue) }
          }
        end

        def validate_initial_claim
          if claims_service.claims_count.zero? && form_attributes['autoCestPDFGenerationDisabled'] == false
            message = 'Veteran has no claims, autoCestPDFGenerationDisabled requires true for Initial Claim'
            raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
          end
        end

        def valid_526_response
          {
            data: {
              type: 'claims_api_auto_established_claim_validation',
              attributes: {
                status: 'valid'
              }
            }
          }.to_json
        end

        def format_526_errors(errors)
          errors.map do |error|
            { status: 422, detail: "#{error['key']} #{error['detail']}", source: error['key'] }
          end
        end

        def track_526_validation_errors(errors)
          StatsD.increment STATSD_VALIDATION_FAIL_KEY

          errors.each do |error|
            key = error['key']&.gsub(/\[(.*?)\]/, '')
            StatsD.increment STATSD_VALIDATION_FAIL_TYPE_KEY, tags: ["key: #{key}"]
          end
        end

        def unprocessable_response(e)
          log_message_to_sentry('Upload error in 526', :error, body: e.message)

          {
            errors: [{ status: 422, detail: e&.message, source: e&.key }]
          }.to_json
        end
      end
    end
  end
end
