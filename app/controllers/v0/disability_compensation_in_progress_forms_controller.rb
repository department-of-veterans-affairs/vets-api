# frozen_string_literal: true

module V0
  class DisabilityCompensationInProgressFormsController < InProgressFormsController
    service_tag 'disability-application'

    def show
      if form_for_user
        # get IPF
        data = data_and_metadata_with_updated_rated_disabilities
        log_started_form_version(data, 'get IPF')
      else
        # create IPF
        data = camelized_prefill_for_user
        log_started_form_version(data, 'create IPF')
      end
      render json: data
    end

    def update
      form_data_present = parsed_form_data.present?

      if Flipper.enabled?(:disability_compensation_sync_modern0781_flow_metadata) &&
         params[:metadata].present? &&
         form_data_present
        params[:metadata][:sync_modern0781_flow] =
          parsed_form_data['sync_modern0781_flow'] || parsed_form_data[:sync_modern0781_flow] || false
      end

      if Flipper.enabled?(:disability_compensation_new_conditions_workflow_metadata) &&
         params[:metadata].present? &&
         form_data_present
        params[:metadata][:new_conditions_workflow] =
          parsed_form_data['disability_comp_new_conditions_workflow'] || false
      end
      super
    end

    private

    def parsed_form_data
      @parsed_form_data ||= begin
        form_data = params[:form_data]
        if form_data.present?
          form_data.is_a?(String) ? JSON.parse(form_data) : form_data
        end
      end
    end

    def form_id
      FormProfiles::VA526ez::FORM_ID
    end

    def data_and_metadata_with_updated_rated_disabilities
      parsed_form_data = JSON.parse(form_for_user.form_data)
      metadata = form_for_user.metadata

      # If EVSS's list of rated disabilities does not match our prefilled rated disabilities
      update_rated_disabilities(parsed_form_data, metadata)

      # for Toxic Exposure 1.1 - add indicator to In Progress Forms
      # moving forward, we don't want to change the version if it is already there
      parsed_form_data = set_started_form_version(parsed_form_data)

      # Fix poisoned IPFs: if disabilityCompNewConditionsWorkflow was erroneously
      # injected as true (by useFormFeatureToggleSync) into a form built under the
      # old flow, the user crashes when returnUrl navigates to an old-flow page
      # whose schemas were never initialized (flag true = old-flow pages inactive).
      # Simple fix: if flag is true and returnUrl is an old-flow conditions page,
      # reset the flag to false so old-flow pages activate properly.
      if Flipper.enabled?(:disability_compensation_fix_poisoned_ipf, @current_user)
        parsed_form_data = fix_new_conditions_workflow_flag(parsed_form_data, metadata)
      end

      # purge duplicate additional information properties in IPFs this error only happens for form created
      # between 2/3/2026-2/9/2026 due to the introduction of duplicate additional information key.
      # this function can be removed after a year or when we know all the IPFs created during
      # that time have successfully submitted.
      # TODO: Remove this cleanup block after 2/9/2027 or once all IPFs created between 2/3/2026 and 2/9/2026
      # have successfully submitted.
      if Flipper.enabled?(:disability_compensation_fix_duplicate_key_ipf, @current_user)
        purge_duplicate_additional_information(parsed_form_data)
      end

      {
        formData: parsed_form_data,
        metadata:
      }
    end

    # Old-flow conditions pages — all wrapped by gatePages(workflow, isNewConditionsOff),
    # so they become inactive when the flag is true.
    #   /new-disabilities/follow-up  — showPagePerItem schemas never initialized → RJSF crash
    #   /new-disabilities/add        — depends returns false → redirect loop
    #   /claim-type                  — depends returns false → redirect loop
    #   /disabilities/orientation    — depends returns false → redirect loop
    #   /disabilities/rated-disabilities — depends returns false → redirect loop
    OLD_FLOW_CONDITIONS_PATTERN = %r{
      claim-type |
      disabilities/orientation |
      disabilities/rated-disabilities |
      new-disabilities/(follow-up|add\b)
    }x

    # If the new-conditions-workflow flag is true and returnUrl points to an
    # old-flow conditions page, reset the flag to false. This prevents the
    # RJSF crash (follow-up) and redirect loops (all other old-flow pages).
    WORKFLOW_FLAG_KEY = 'disability_comp_new_conditions_workflow'

    def fix_new_conditions_workflow_flag(form_data, metadata)
      flag = form_data[WORKFLOW_FLAG_KEY]
      return_url = metadata&.dig('returnUrl') || metadata&.dig('return_url') || ''

      return form_data unless [true, 'true'].include?(flag)

      unless OLD_FLOW_CONDITIONS_PATTERN.match?(return_url)
        log_poisoned_ipf_fix('returnUrl not an old-flow conditions page, skipping', flag:, return_url:)
        return form_data
      end

      log_poisoned_ipf_fix('resetting to false — flag true + old-flow returnUrl', flag:, return_url:)
      corrected = form_data.merge(WORKFLOW_FLAG_KEY => false)
      begin
        form_for_user.update!(form_data: corrected.to_json)
      rescue => e
        Rails.logger.error("Form526 fix_poisoned_ipf: failed to persist - #{e.message}")
      end
      corrected
    end

    def log_poisoned_ipf_fix(message, flag: nil, return_url: nil)
      Rails.logger.info("Form526 fix_poisoned_ipf: #{message}",
                        user_uuid: @current_user&.uuid,
                        in_progress_form_id: form_for_user&.id,
                        flag_ipf_value: flag,
                        return_url:)
    end

    def set_started_form_version(data)
      # Only set default if BOTH keys are missing (using && instead of ||)
      if data['started_form_version'].blank? && data['startedFormVersion'].blank?
        log_started_form_version(data, 'existing IPF missing startedFormVersion')
        data['startedFormVersion'] = '2019'
      end
      data
    end

    def rated_disabilities_evss
      @rated_disabilities_evss ||= FormProfiles::VA526ez.for(form_id:, user: @current_user)
                                                        .initialize_rated_disabilities_information
    rescue
      # if the call to EVSS fails we can skip updating. EVSS fails around an hour each night.
      nil
    end

    def update_rated_disabilities(form_data, metadata)
      if rated_disabilities_evss.present? &&
         arr_to_compare(form_data&.dig('ratedDisabilities')) !=
         arr_to_compare(rated_disabilities_evss&.rated_disabilities&.map(&:attributes))

        if form_data['ratedDisabilities'].present? &&
           form_data.dig('view:claimType', 'view:claimingIncrease')
          metadata['returnUrl'] = '/disabilities/rated-disabilities'
          if form_data[WORKFLOW_FLAG_KEY] == true || form_data[WORKFLOW_FLAG_KEY] == 'true'
            metadata['returnUrl'] = '/conditions/summary'
          end
        end
        # Use as_json instead of JSON.parse(to_json) to avoid string allocation overhead
        evss_rated_disabilities = rated_disabilities_evss&.rated_disabilities&.map(&:as_json)
        form_data['updatedRatedDisabilities'] = camelize_with_olivebranch(evss_rated_disabilities)
      end
    end

    def purge_duplicate_additional_information(form_data)
      %w[additionalInformation additional_information].each do |key|
        value = form_data[key]
        form_data.delete(key) unless value.is_a?(String)
      end
    end

    def arr_to_compare(rated_disabilities)
      rated_disabilities&.collect do |rd|
        diagnostic_code = rd['diagnostic_code'] || rd['diagnosticCode']
        rated_disability_id = rd['rated_disability_id'] || rd['ratedDisabilityId']
        "#{diagnostic_code}#{rated_disability_id}#{rd['name']}"
      end&.sort
    end

    # temp: for https://github.com/department-of-veterans-affairs/va.gov-team/issues/97932
    # tracking down a possible issue with prefill
    def log_started_form_version(data, location)
      # Handle different data structures from different call sites:
      # - From show method: {formData: ..., metadata: ...} with symbol keys
      # - From set_started_form_version: raw form data hash with string keys
      form_data = data[:formData] || data['formData'] || data[:form_data] || data['form_data'] || data
      started_form_version = form_data&.dig('startedFormVersion') || form_data&.dig(:startedFormVersion) ||
                             form_data&.dig('started_form_version') || form_data&.dig(:started_form_version)

      if started_form_version.present?
        Rails.logger.info("Form526 InProgressForm startedFormVersion = #{started_form_version} #{location}")
      else
        raise Common::Exceptions::ServiceError.new(
          detail: "no startedFormVersion detected in #{location}",
          source: 'DisabilityCompensationInProgressFormsController#show'
        )
      end
    rescue => e
      Rails.logger.error("Form526 InProgressForm startedFormVersion retrieval failed #{location} #{e.message}")
    end
  end
end
