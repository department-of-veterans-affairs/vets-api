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
      if rated_disabilities_evss.present? &&
         arr_to_compare(parsed_form_data&.dig('ratedDisabilities')) !=
         arr_to_compare(rated_disabilities_evss&.rated_disabilities&.map(&:attributes))

        if parsed_form_data['ratedDisabilities'].present? &&
           parsed_form_data.dig('view:claimType', 'view:claimingIncrease')
          metadata['returnUrl'] = '/disabilities/rated-disabilities'
        end
        # Use as_json instead of JSON.parse(to_json) to avoid string allocation overhead
        evss_rated_disabilities = rated_disabilities_evss&.rated_disabilities&.map(&:as_json)
        parsed_form_data['updatedRatedDisabilities'] = camelize_with_olivebranch(evss_rated_disabilities)
      end

      # for Toxic Exposure 1.1 - add indicator to In Progress Forms
      # moving forward, we don't want to change the version if it is already there
      parsed_form_data = set_started_form_version(parsed_form_data)

      # Fix poisoned IPFs: if disabilityCompNewConditionsWorkflow was erroneously
      # injected as true (by useFormFeatureToggleSync) into a form built under the
      # old flow, the user would hit a redirect loop because old-flow pages are
      # hidden when the flag is true. Data-first detection with Flipper tiebreaker:
      # - New-flow data exists (ratedDisability key) → keep true (user is locked in)
      # - Old-flow data exists (items without ratedDisability) → reset (poisoned form)
      # - No conditions data at all + Flipper ON → keep true (hasn't reached that step)
      # - No conditions data at all + Flipper OFF → reset (flag was erroneously injected)
      if Flipper.enabled?(:disability_compensation_fix_poisoned_ipf, @current_user)
        parsed_form_data = fix_new_conditions_workflow_flag(parsed_form_data, metadata)
      end
      {
        formData: parsed_form_data,
        metadata:
      }
    end

    # Entry point: checks if the disabilityCompNewConditionsWorkflow flag needs fixing.
    # The flag may be boolean true or string "true" depending on how it was injected
    # by useFormFeatureToggleSync. If the flag isn't truthy, no action is needed.
    def fix_new_conditions_workflow_flag(form_data, _metadata)
      flag = form_data['disabilityCompNewConditionsWorkflow']

      unless [true, 'true'].include?(flag)
        log_poisoned_ipf_decision('flag not true, skipping', flag)
        return form_data
      end

      decision = poisoned_ipf_decision(form_data)

      log_poisoned_ipf_decision(decision[:message], flag, decision[:details])
      return form_data if decision[:keep]

      reset_workflow_flag(form_data)
    end

    # Data-first decision logic with Flipper tiebreaker only for the no-data case.
    # - Definitive new-flow data (ratedDisability, conditionDate, or sideOfBody on items)
    #   → user is locked into new flow, keep flag true
    # - Definitive old-flow data (view:*FollowUp wrappers, cause without conditionDate)
    #   → poisoned form, reset to false
    # - Ambiguous items (condition-only, no definitive signal either way)
    #   → reset to false (crash risk: old-flow showPagePerItem schemas uninitialized)
    # - No newDisabilities data at all (absent or empty array)
    #   → Flipper tiebreaker: ON = legitimate user from prefill, OFF = injected flag
    #   (no items means no showPagePerItem crash risk, safe to keep true)
    def poisoned_ipf_decision(form_data)
      has_new_data = new_flow_data?(form_data)
      has_old_data = old_flow_data?(form_data)
      has_items = form_data['newDisabilities'].present?
      flipper_on = Flipper.enabled?(:disability_compensation_new_conditions_workflow, @current_user)
      details = { flipper: flipper_on, has_new_flow_data: has_new_data, has_old_flow_data: has_old_data,
                  has_items: }

      if has_new_data
        { keep: true, message: 'keeping true — new-flow data present (user locked in)', details: }
      elsif has_items
        reason = has_old_data ? 'old-flow data detected' : 'ambiguous items (crash risk)'
        { keep: false, message: "resetting to false — #{reason}", details: }
      elsif flipper_on
        { keep: true, message: 'keeping true — no items + Flipper ON (legitimate prefill)', details: }
      else
        { keep: false, message: 'resetting to false — no items + Flipper OFF (injected flag)', details: }
      end
    end

    # Persist the corrected flag so it survives even if auto-save doesn't fire
    # before the next page load
    def reset_workflow_flag(form_data)
      corrected = form_data.merge('disabilityCompNewConditionsWorkflow' => false)
      begin
        form_for_user.update(form_data: corrected.to_json)
      rescue => e
        Rails.logger.error("Form526 fix_poisoned_ipf: failed to persist - #{e.message}")
      end
      corrected
    end

    def log_poisoned_ipf_decision(message, flag_value, details = {})
      Rails.logger.info("Form526 fix_poisoned_ipf: #{message}",
                        user_uuid: @current_user&.uuid,
                        in_progress_form_id: form_for_user&.id,
                        flag_ipf_value: flag_value,
                        **details)
    end

    # Definitive new-flow signals: keys that ONLY the new conditions workflow sets.
    # ratedDisability — set on conditions/:index/condition page
    # conditionDate — set on new-condition-date or rated-disability-date page
    # sideOfBody — set on side-of-body page (conditional)
    # Items with only 'condition' are ambiguous (both flows produce them).
    def new_flow_data?(form_data)
      new_disabilities = form_data['newDisabilities']
      return false if new_disabilities.blank?

      new_flow_keys = %w[ratedDisability conditionDate sideOfBody]
      new_disabilities.any? { |item| new_flow_keys.any? { |key| item&.key?(key) } }
    end

    # Definitive old-flow signals: keys/patterns that ONLY the old conditions workflow produces.
    # view:secondaryFollowUp, view:worsenedFollowUp, view:vaFollowUp — old flow nests
    #   cause-specific fields in wrapper objects; new flow flattens them.
    # cause WITHOUT conditionDate — old flow sets cause on its single follow-up page
    #   but never sets conditionDate. New flow always sets conditionDate before cause.
    # Items with only 'condition' are ambiguous (both flows produce them).
    def old_flow_data?(form_data)
      new_disabilities = form_data['newDisabilities']
      return false if new_disabilities.blank?

      old_flow_wrapper_keys = %w[view:secondaryFollowUp view:worsenedFollowUp view:vaFollowUp]
      new_disabilities.any? do |item|
        old_flow_wrapper_keys.any? { |key| item&.key?(key) } ||
          (item&.key?('cause') && !item&.key?('conditionDate'))
      end
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
