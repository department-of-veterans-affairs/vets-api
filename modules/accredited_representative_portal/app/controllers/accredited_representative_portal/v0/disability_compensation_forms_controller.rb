# frozen_string_literal: true

require 'evss/common_service'
require 'evss/disability_compensation_auth_headers'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/service'
require 'lighthouse/benefits_reference_data/response_strategy'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/loggers/monitor'

module AccreditedRepresentativePortal
  module V0
    class DisabilityCompensationFormsController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern

      service_tag 'disability-application'
      before_action :authorize_submission, only: [:submit_all_claim]

      def submit_all_claim
        temp_separation_location_fix if Flipper.enabled?(:disability_compensation_temp_separation_location_code_string,
                                                         @current_user)

        temp_toxic_exposure_optional_dates_fix if Flipper.enabled?(
          :disability_compensation_temp_toxic_exposure_optional_dates_fix,
          @current_user
        )

        saved_claim = ::SavedClaim::DisabilityCompensation::Form526AllClaim.from_hash(form_content)
        if Flipper.enabled?(:disability_compensation_sync_modern0781_flow_metadata) && form_content['form526'].present?
          saved_claim.metadata = add_0781_metadata(form_content['form526'])
        end

        saved_claim.save ? log_success(saved_claim) : log_failure(saved_claim)
        submission = create_submission(saved_claim)
        # if jid = 0 then the submission was prevented from going any further in the process
        jid = 0

        # Feature flag to stop submission from being submitted to third-party service
        # With this on, the submission will NOT be processed by EVSS or Lighthouse,
        # nor will it go to VBMS,
        # but the line of code before this one creates the submission in the vets-api database
        if Flipper.enabled?(:disability_compensation_prevent_submission_job, @current_user)
          Rails.logger.info("Submission ID: #{submission.id} prevented from sending to third party service.")
        else
          jid = submission.start
        end

        render json: { data: { attributes: { job_id: jid } } },
               status: :ok
      end

      private

      def authorize_submission
        Rails.logger.info "ARP: Looking up claimant with metadata: #{metadata.inspect}"
        
        claimant_icn.present? or
          raise Common::Exceptions::RecordNotFound,
                'Could not lookup claimant with given information.'
        
        Rails.logger.info "ARP: Found claimant_icn=#{claimant_icn}, claimant_representative=#{claimant_representative.inspect}"

        authorize(
          claimant_representative,
          policy_class: RepresentativeFormUploadPolicy
        )
      end

      def form_content
        @form_content ||= begin
          parsed = JSON.parse(request.body.string)

          inner_form = parsed.dig('form526', 'form526')
          raise Common::Exceptions::ParameterMissing.new('form526.form526') unless inner_form.is_a?(Hash)

          unless inner_form.key?('isVaEmployee')
            raise Common::Exceptions::ParameterMissing.new('form526.form526.isVaEmployee')
          end

          unless inner_form.key?('standardClaim')
            raise Common::Exceptions::ParameterMissing.new('form526.form526.standardClaim')
          end

          flattened = parsed.dup
          flattened['form526'] = inner_form
          flattened['isVaEmployee'] = inner_form['isVaEmployee']
          flattened['standardClaim'] = inner_form['standardClaim']
          flattened
        end
      end

      # Override the concern's metadata method to extract from form526 structure
      def metadata
        @metadata ||=
          {}.tap do |memo|
            # For Form 526, we expect the veteran identifying information to be passed
            # in a similar structure to other representative forms
            # The form526 structure itself doesn't include SSN/DOB for privacy
            veteran_info = form_content['veteran'] || {}

            memo[:veteran] = {
              ssn: veteran_info['ssn'],
              dateOfBirth: veteran_info['dateOfBirth'],
              postalCode: veteran_info['postalCode'],
              name: {
                first: veteran_info.dig('fullName', 'first'),
                last: veteran_info.dig('fullName', 'last')
              }
            }

            # Form 526 typically doesn't have a dependent/claimant separate from veteran
            memo[:dependent] = nil
          end
      end

      # The concern's claimant_icn and claimant_representative methods will work with the overridden metadata

      def add_0781_metadata(form526)
        if form526['syncModern0781Flow'].present?
          { sync_modern0781_flow: form526['syncModern0781Flow'],
            sync_modern0781_flow_answered_online: form526['form0781'].present? }.to_json
        end
      end

      def create_submission(saved_claim)
        Rails.logger.info('Creating 526 submission', user_uuid: @current_user&.uuid, saved_claim_id: saved_claim&.id)
        
        # For representative portal, we need the veteran's UserAccount
        # The current_user is the representative, so we look up the veteran by ICN
        veteran_icn = claimant_icn
        veteran_user_account = UserAccount.find_by(icn: veteran_icn)
        
        # If no UserAccount exists, we'll need to create one
        veteran_user_account ||= create_veteran_user_account(veteran_icn)
        
        submission = Form526Submission.new(
          user_uuid: veteran_user_account.id, # UserAccount id serves as user_uuid for persistent storage
          user_account: veteran_user_account,
          saved_claim_id: saved_claim.id,
          auth_headers_json: build_auth_headers_for_veteran.to_json,
          form_json: normalized_form_for_submission.to_json,
          submit_endpoint: 'claims_api'
        )

        if missing_disabilities?(submission)
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: 'no new or increased disabilities were submitted', source: 'DisabilityCompensationFormsController'
          )
        end

        submission.save! && submission
      rescue PG::NotNullViolation => e
        Rails.logger.error(
          'Creating 526 submission: PG::NotNullViolation', user_uuid: @current_user&.uuid, saved_claim_id: saved_claim&.id
        )
        raise e
      end

      # Create a UserAccount for the veteran based on MPI data
      def create_veteran_user_account(icn)
        UserAccount.create!(icn: icn)
      end

      # Build auth headers for the veteran based on the form data
      # Since we don't have an active User session for the veteran,
      # we build minimal headers from the form data and MPI lookup
      def build_auth_headers_for_veteran
        veteran_metadata = metadata[:veteran]
        # Get the MPI profile that was already looked up during authorization
        profile = get_mpi_profile
        
        {
          'va_eauth_pnid' => veteran_metadata[:ssn],
          'va_eauth_firstName' => veteran_metadata.dig(:name, :first),
          'va_eauth_lastName' => veteran_metadata.dig(:name, :last),
          'va_eauth_birthdate' => veteran_metadata[:dateOfBirth],
          'va_eauth_issueinstant' => Time.current.iso8601,
          'va_eauth_dodedipnid' => profile&.edipi,
          'va_eauth_birlsfilenumber' => profile&.birls_id,
          'va_eauth_pid' => profile&.participant_id,
          'va_eauth_pnidtype' => 'SSN',
          'va_eauth_icn' => claimant_icn
        }.compact
      end

      # Get the MPI profile for the veteran
      # This reuses the MPI lookup that was already done in claimant_icn
      def get_mpi_profile
        veteran_metadata = metadata[:veteran]
        mpi_response = MPI::Service.new.find_profile_by_attributes(
          ssn: veteran_metadata[:ssn],
          first_name: veteran_metadata.dig(:name, :first),
          last_name: veteran_metadata.dig(:name, :last),
          birth_date: veteran_metadata[:dateOfBirth]
        )
        mpi_response&.profile
      rescue => e
        Rails.logger.error("Error fetching MPI profile: #{e.message}")
        nil
      end

      def log_failure(claim)
        if Flipper.enabled?(:disability_526_track_saved_claim_error) && claim&.errors
          begin
            in_progress_form =
              @current_user ? InProgressForm.form_for_user(FormProfiles::VA526ez::FORM_ID, @current_user) : nil
          ensure
            monitor.track_saved_claim_save_error(
              # Array of ActiveModel::Error instances from the claim that failed to save
              claim&.errors&.errors,
              in_progress_form&.id,
              @current_user.uuid
            )
          end
        end

        raise Common::Exceptions::ValidationErrors, claim
      end

      def log_success(claim)
        monitor.track_saved_claim_save_success(
          claim,
          @current_user.uuid
        )
      end

      def stats_key
        'api.accredited_representative_portal.disability_compensation'
      end

      def missing_disabilities?(submission)
        disabilities = submission.form.dig('form526', 'form526', 'disabilities') || []
        if disabilities.none?
          StatsD.increment("#{stats_key}.failure")
          Rails.logger.error(
            'Creating 526 submission: no new or increased disabilities were submitted', user_uuid: @current_user&.uuid
          )
          return true
        end
        false
      end

      def normalized_form_for_submission
        {
          'form526' => {
            'form526' => form_content['form526']
          }
        }
      end

      # TEMPORARY
      # Turn separation location into string
      # 11/18/2024 BRD EVSS -> Lighthouse migration caused separation location to turn into an integer,
      # while SavedClaim (vets-json-schema) is expecting a string
      def temp_separation_location_fix
        if form_content.is_a?(Hash) && form_content['form526'].is_a?(Hash)
          separation_location_code = form_content.dig('form526', 'serviceInformation', 'separationLocation',
                                                      'separationLocationCode')
          unless separation_location_code.nil?
            form_content['form526']['serviceInformation']['separationLocation']['separationLocationCode'] =
              separation_location_code.to_s
          end
        end
      end

      # [Toxic Exposure] Users are failing SavedClaim creation when exposure dates are incomplete, i.e. "XXXX-01-XX"
      # #106340 - https://github.com/department-of-veterans-affairs/va.gov-team/issues/106340
      # malformed dates are coming through because the forms date component does not validate data if the user
      # backs out of any Toxic Exposure section
      # This temporary fix:
      # 1. removes the malformed dates from the Toxic Exposure section
      # 2. logs which section had the bad date to track which sections users are backing out of
      def temp_toxic_exposure_optional_dates_fix
        return unless form_content.is_a?(Hash) && form_content['form526'].is_a?(Hash)

        toxic_exposure = form_content.dig('form526', 'toxicExposure')
        return unless toxic_exposure

        transformer = EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new
        prefix = 'AccreditedRepresentativePortal::V0::DisabilityCompensationFormsController#submit_all_claim temp_toxic_exposure_optional_dates_fix:'

        Form526Submission::TOXIC_EXPOSURE_DETAILS_MAPPING.each_key do |key|
          next unless toxic_exposure[key].is_a?(Hash)

          # Fix malformed dates for each sub-location
          toxic_exposure[key].each do |location, values|
            next unless values.is_a?(Hash)

            fix_date_error(values, 'startDate', { prefix:, section: key, location: }, transformer)
            fix_date_error(values, 'endDate',   { prefix:, section: key, location: }, transformer)
          end

          # Also fix malformed top-level dates if needed
          next unless %w[otherHerbicideLocations specifyOtherExposures].include?(key)

          fix_date_error(toxic_exposure[key], 'startDate', { prefix:, section: key }, transformer)
          fix_date_error(toxic_exposure[key], 'endDate',   { prefix:, section: key }, transformer)
        end
      end

      def fix_date_error(hash, date_key, context, transformer)
        return if hash[date_key].blank?

        date = transformer.send(:convert_date_no_day, hash[date_key])
        return if date.present?

        hash.delete(date_key)
        # If `context[:location]` is nil, this squeezes out the extra space
        Rails.logger.info(
          "#{context[:prefix]} #{context[:section]} #{context[:location]} #{date_key} was malformed"
            .squeeze(' ')
        )
      end
      # END TEMPORARY

      def monitor
        @monitor ||= DisabilityCompensation::Loggers::Monitor.new
      end
    end
  end
end
