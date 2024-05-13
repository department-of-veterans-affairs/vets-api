# frozen_string_literal: true

module Vye
  module NeedsEnrollmentVerification
    private

    attr_accessor :award
    attr_reader :today, :verification

    def compare_date_to_now_return_boolean(date)
      date < today
    end

    def compare_two_dates_return_boolean(date1, date2)
      date1 < date2
    end

    def last_day_of_previous_month
      today.beginning_of_month - 1.day
    end

    def current_rec_ended
      @current_award_indicator == 'C' && compare_two_dates_return_boolean(@award.award_end_date, today)
    end

    def are_dates_the_same(date1, date2)
      date1 == date2
    end

    # date_last_certified is before award_begin_date
    def dlc_before_abd?
      compare_two_dates_return_boolean(date_last_certified, @award.award_begin_date)
    end

    # date_last_certified is before last day of previous month
    def dlc_before_ldpm?
      compare_two_dates_return_boolean(date_last_certified, last_day_of_previous_month)
    end

    # last day of previous month is before award_begin_date
    def ldpm_before_abd?
      compare_two_dates_return_boolean(last_day_of_previous_month, @award.award_begin_date)
    end

    # last day of previous month is before award_end_date
    def ldpm_before_aed?
      compare_two_dates_return_boolean(last_day_of_previous_month, @award.award_end_date)
    end

    # award_end_date is before today
    def aed_before_today?
      compare_date_to_now_return_boolean(@award.award_end_date)
    end

    def last_day_of_month?
      today == today.end_of_month
    end

    def setup
      @today = Time.zone.today
      @enrollments = []
      @supress_future_award = false
      clear_case_variable
      clear_cert_variables
    end

    def extract_from(award:)
      @award = award

      @award_end_date_minus_one_day = @award.award_end_date - 1.day
      @current_award_indicator = @award.cur_award_ind
    end

    def clear_case_variable
      @case_award_id = nil
      @case_start_date = nil
      @case_end_date = nil
      @case_credit_hours = nil
      @case_monthly_rate = nil
      @case_payment_date = nil
      @case_trace = nil
    end

    def clear_cert_variables
      @open_cert = false
      @open_cert_award_id = nil
      @open_cert_credit_hours = nil
      @open_cert_monthly_rate = nil
      @open_cert_payment_date = nil
    end

    def add_enrollment_to_enrollments
      user_profile = self.user_profile
      award_id = @case_award_id
      act_begin = @case_start_date
      act_end = @case_end_date
      number_hours = @case_credit_hours
      monthly_rate = @case_monthly_rate
      payment_date = @case_payment_date
      trace = @case_trace

      verification = Verification.build(
        user_profile:, award_id:,
        act_begin:, act_end:,
        number_hours:, monthly_rate:,
        payment_date:, trace:
      )

      @enrollments.push(verification)

      clear_case_variable
    end

    def eval_case_eom
      return unless dlc_before_ldpm?
      return unless last_day_of_month?
      return unless @award.award_begin_date < today
      return if aed_before_today?
      return unless dlc_before_abd?

      @case_award_id = @award.id
      @case_start_date = @award.award_begin_date
      @case_end_date = today
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case_eom

      add_enrollment_to_enrollments
    end

    def flag_open_cert
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return if @award.award_end_date.present?

      @open_cert = true
      @open_cert_award_id = @award.id
      @open_cert_credit_hours = @award.number_hours
      @open_cert_monthly_rate = @award.monthly_rate
      @open_cert_payment_date = @award.payment_date
    end

    def eval_case1a
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)
      return unless current_rec_ended
      return unless ldpm_before_aed?
      return unless are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      @case_award_id = @award.id
      @case_start_date = date_last_certified
      @case_end_date = last_day_of_previous_month
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case1a

      @supress_future_award = true

      add_enrollment_to_enrollments
    end

    def eval_case1b
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)
      return unless current_rec_ended

      @case_award_id = @award.id
      @case_start_date = date_last_certified
      @case_end_date = @award_end_date_minus_one_day
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case1b

      add_enrollment_to_enrollments
    end

    def eval_case2
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)
      return unless ldpm_before_aed?
      return if ldpm_before_abd?

      @case_award_id = @award.id
      @case_start_date = date_last_certified
      @case_end_date = last_day_of_previous_month
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case2

      add_enrollment_to_enrollments
    end

    def eval_case3
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return if @award.award_end_date.blank?
      return if are_dates_the_same(@award.award_end_date, date_last_certified)

      @case_award_id = @award.id
      @case_start_date = date_last_certified
      @case_end_date = @award_end_date_minus_one_day
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case3

      add_enrollment_to_enrollments
    end

    def eval_case4
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supress_future_award
      return unless @open_cert
      return unless ldpm_before_abd?

      @case_award_id = @open_cert_award_id
      @case_start_date = date_last_certified
      @case_end_date = last_day_of_previous_month
      @case_credit_hours = @open_cert_credit_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @open_cert_payment_date
      @case_trace = :case4

      add_enrollment_to_enrollments
      clear_cert_variables
    end

    def eval_case5
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supress_future_award
      return unless @open_cert
      return unless ldpm_before_aed?
      return if ldpm_before_abd?

      @case_award_id = @open_cert_award_id
      @case_start_date = date_last_certified
      @case_end_date = @award_end_date_minus_one_day
      @case_credit_hours = @open_cert_credit_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @open_cert_payment_date
      @case_trace = :case5

      add_enrollment_to_enrollments
      clear_cert_variables
    end

    def eval_case6
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supress_future_award
      return if ldpm_before_abd?
      return if date_last_certified.present?

      @case_award_id = @award.id
      @case_start_date = @award.award_begin_date
      @case_end_date = last_day_of_previous_month
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case6

      add_enrollment_to_enrollments
    end

    def eval_case7
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supress_future_award
      return if ldpm_before_abd?
      return unless ldpm_before_aed?

      @case_award_id = @award.id
      @case_start_date = @award.award_begin_date
      @case_end_date = last_day_of_previous_month
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case7

      add_enrollment_to_enrollments
    end

    def eval_case8
      return unless dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supress_future_award
      return if ldpm_before_abd?

      @case_award_id = @award.id
      @case_start_date = @award.award_begin_date
      @case_end_date = @award_end_date_minus_one_day
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case8

      add_enrollment_to_enrollments
    end

    def eval_case9
      return if dlc_before_ldpm?
      return unless aed_before_today?
      return unless are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      @case_award_id = @award.id
      @case_start_date = date_last_certified
      @case_end_date = @award_end_date_minus_one_day
      @case_credit_hours = @award.number_hours
      @case_monthly_rate = @award.monthly_rate
      @case_payment_date = @award.payment_date
      @case_trace = :case9

      add_enrollment_to_enrollments
    end

    public

    def enrollments
      return [] if queued_verifications?
      return @enrollments if defined?(@enrollments)

      setup
      awards.each do |award|
        extract_from(award:)

        eval_case_eom
        flag_open_cert || eval_case1a || eval_case1b || eval_case2 || eval_case3
        eval_case4 || eval_case5
        eval_case6 || eval_case7 || eval_case8
        eval_case9
      end

      @enrollments
    end

    alias pending_verifications enrollments
  end
end
