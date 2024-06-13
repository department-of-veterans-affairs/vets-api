# frozen_string_literal: true

module Vye
  module NeedsEnrollmentVerification
    def enrollments
      return [] if queued_verifications?
      return @enrollments if defined?(@enrollments)

      setup
      awards.each do |award|
        @award = award

        eval_case_eom
        flag_open_cert || eval_case1a || eval_case1b || eval_case2 || eval_case3
        eval_case4 || eval_case5
        eval_case6 || eval_case7 || eval_case8
        eval_case9
      end

      @enrollments
    end

    alias pending_verifications enrollments

    private

    attr_accessor :award
    attr_reader :today

    def last_day_of_previous_month
      today.beginning_of_month - 1.day
    end

    def current_rec_ended
      @award.award_ind_current? && (@award.award_end_date < today)
    end

    def are_dates_the_same(date1, date2)
      date1 == date2
    end

    # date_last_certified is before award_begin_date
    def dlc_before_abd?
      date_last_certified < @award.award_begin_date
    end

    # date_last_certified is before last day of previous month
    def dlc_before_ldpm?
      date_last_certified < last_day_of_previous_month
    end

    # last day of previous month is before award_begin_date
    def ldpm_before_abd?
      last_day_of_previous_month < @award.award_begin_date
    end

    # last day of previous month is before award_end_date
    def ldpm_before_aed?
      last_day_of_previous_month < @award.award_end_date
    end

    # award_begin_date is before today
    def abd_before_today?
      @award.award_begin_date < today
    end

    # award_end_date is before today
    def aed_before_today?
      @award.award_end_date < today
    end

    def last_day_of_month?
      today == today.end_of_month
    end

    def setup
      @today = Time.zone.today
      @enrollments = []
      @supress_future_award = false
      clear_cert_variables
    end

    def clear_cert_variables
      @open_cert = false
      @open_cert_award_id = nil
      @open_cert_credit_hours = nil
      @open_cert_monthly_rate = nil
      @open_cert_payment_date = nil
    end

    def push_enrollment(**attributes)
      @enrollments.push(
        Verification.build(user_profile:, **attributes)
      )

      true
    end

    def eval_case_eom
      return unless dlc_before_ldpm?
      return unless last_day_of_month?
      return unless abd_before_today?
      return if aed_before_today?
      return unless dlc_before_abd?

      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: today,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case_eom
      )
    end

    def flag_open_cert
      return unless dlc_before_ldpm?
      return unless @award.award_ind_current?
      return if @award.award_end_date.present?

      @open_cert = true
      @open_cert_award_id = @award.id
      @open_cert_credit_hours = @award.number_hours
      @open_cert_monthly_rate = @award.monthly_rate
      @open_cert_payment_date = @award.payment_date
    end

    def eval_case1a
      return unless dlc_before_ldpm?
      return unless @award.award_ind_current?
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)
      return unless current_rec_ended
      return unless ldpm_before_aed?
      return unless are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      @supress_future_award = true

      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case1a
      )
    end

    def eval_case1b
      return unless dlc_before_ldpm?
      return unless @award.award_ind_current?
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)
      return unless current_rec_ended

      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: @award.award_end_date - 1.day,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case1b
      )
    end

    def eval_case2
      return unless dlc_before_ldpm?
      return unless @award.award_ind_current?
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)
      return unless ldpm_before_aed?
      return if ldpm_before_abd?

      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case2
      )
    end

    def eval_case3
      return unless dlc_before_ldpm?
      return unless @award.award_ind_current?
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)

      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: @award.award_end_date - 1.day,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case3
      )
    end

    def eval_case4
      return unless dlc_before_ldpm?
      return unless @award.award_ind_future?
      return if @supress_future_award
      return unless @open_cert
      return unless ldpm_before_abd?

      push_enrollment(
        award_id: @open_cert_award_id,
        act_begin: date_last_certified,
        act_end: last_day_of_previous_month,
        number_hours: @open_cert_credit_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @open_cert_payment_date,
        trace: :case4
      )
      clear_cert_variables

      true
    end

    def eval_case5
      return unless dlc_before_ldpm?
      return unless @award.award_ind_future?
      return if @supress_future_award
      return unless @open_cert
      return unless ldpm_before_aed?
      return if ldpm_before_abd?

      push_enrollment(
        award_id: @open_cert_award_id,
        act_begin: date_last_certified,
        act_end: @award.award_end_date - 1.day,
        number_hours: @open_cert_credit_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @open_cert_payment_date,
        trace: :case5
      )
      clear_cert_variables

      true
    end

    def eval_case6
      return unless dlc_before_ldpm?
      return unless @award.award_ind_future?
      return if @supress_future_award
      return if ldpm_before_abd?
      return if date_last_certified.present?

      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case6
      )
    end

    def eval_case7
      return unless dlc_before_ldpm?
      return unless @award.award_ind_future?
      return if @supress_future_award
      return if ldpm_before_abd?
      return unless ldpm_before_aed?

      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case7
      )
    end

    def eval_case8
      return unless dlc_before_ldpm?
      return unless @award.award_ind_future?
      return if @supress_future_award
      return if ldpm_before_abd?

      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: @award.award_end_date - 1.day,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case8
      )

      true
    end

    def eval_case9
      return if dlc_before_ldpm?
      return unless aed_before_today?
      return unless are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: @award.award_end_date - 1.day,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case9
      )

      true
    end
  end
end
