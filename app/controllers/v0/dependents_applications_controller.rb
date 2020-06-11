# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    def create
      # dependents_hash = dependent_params.to_h
      # dependents_hash = params
      bgs_dependent_service.modify_dependents(nil)
      render json: {status: 'ok'}
    end

    def show
      dependents = bgs_dependent_service.get_dependents
      render json: dependents, serializer: DependentsSerializer
    rescue => e
      log_exception_to_sentry(e)
      raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
    end

    def disability_rating
      res = EVSS::Dependents::RetrievedInfo.for_user(current_user)
      render json: { has30_percent: res.body.dig('submitProcess', 'application', 'has30Percent') }
    end

    private

    def bgs_dependent_service
      @bgs_dependent_service ||= BGS::DependentService.new(current_user)
    end

    def dependent_params
      params.permit(
        :add_child,
        :add_spouse,
        :child_stopped_attending_school,
        :child_marriage,
        :current_term_dates,
        :current_marriage_information,
        :does_live_with_spouse,
        :last_term_school_information,
        :program_information,
        :privacy_agreement_accepted,
        :report674,
        :report_divorce,
        :report_death,
        :report_stepchild_not_in_household,
        :report_marriage_of_child_under18,
        :report_child18_or_older_is_not_attending_school,
        :school_information,
        :spouse_marriage_history,
        :spouse_was_married_before,
        :student_address_marriage_tuition,
        :student_name_and_ssn,
        :student_does_have_networth,
        :student_does_earn_income,
        :student_earnings_from_school_year,
        :student_will_earn_income_next_year,
        :student_expected_earnings_next_year,
        :student_did_attend_school_last_term,
        :veteran_marriage_history,
        :veteran_was_married_before,
        :veteran_marriage_history,
        children_to_add: [],
        deaths: [],
        step_children: [],
        dependents_application: {},
        more_veteran_information: {},
        spouse_information: {},
        student_networth_information: {},
        veteran_address: {},
        veteran_information: {},
        veteran_contact_information: {}
      )
    end
  end
end
