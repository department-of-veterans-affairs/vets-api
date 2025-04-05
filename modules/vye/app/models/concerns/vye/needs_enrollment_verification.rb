# frozen_string_literal: true

# This is included from UserInfo

# rubocop:disable Rails/Output
# rubocop:disable Style/StringLiterals
# rubocop:disable Layout/LineLength
module Vye
  module NeedsEnrollmentVerification
    def enrollments
      return [] if queued_verifications?
      return @enrollments if defined?(@enrollments)

      setup
      puts "\n\n*** processing awards current date is #{today}"
      awards.each_with_index do |award, idx|
        # cur_award_ind is passed in from the feed, we do not determine it.
        puts "\n\n"
        puts "*** processing award #{(idx + 1)} of #{awards.size} ***"
        @award = award
        puts "award_begin_date: #{award.award_begin_date}"
        puts "award_end_date:   #{award.award_end_date}"
        puts "date_last_certified: #{date_last_certified}"
        puts "award_ind_past?: #{award.award_ind_past?}"
        puts "award_ind_current?: #{award.award_ind_current?}"
        puts "award_ind_future?: #{award.award_ind_future?}"
        puts "@suppress_future_award: #{@supress_future_award}"
        puts "@open_cert: #{@open_cert}"
        puts "current_rec_ended?: #{current_rec_ended?}"

        eval_case_eom

        next if flag_open_cert
        next if eval_case1a
        next if eval_case1b
        next if eval_case2
        next if eval_case3
        next if eval_case4
        next if eval_case5
        next if eval_case6
        next if eval_case7
        next if eval_case8
        next if eval_case9
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

    def aed_minus1
      return nil if @award.award_end_date.blank?

      @award.award_end_date - 1.day
    end

    def current_rec_ended?
      @award.award_ind_current? && aed_before_today?
    end

    def are_dates_the_same(date1, date2)
      return false if date1.blank? && date2.blank?

      date1 == date2
    end

    # date_last_certified is before award_begin_date
    def dlc_before_abd? = in_order?(first: date_last_certified, second: @award.award_begin_date)

    # date_last_certified is before last day of previous month
    def dlc_before_ldpm? = in_order?(first: date_last_certified, second: last_day_of_previous_month)

    # last day of previous month is before award_begin_date
    def ldpm_before_abd? = in_order?(first: last_day_of_previous_month, second: @award.award_begin_date)

    # last day of previous month is before award_end_date
    def ldpm_before_aed? = in_order?(first: last_day_of_previous_month, second: @award.award_end_date)

    # award_begin_date is before today
    def abd_before_today? = in_order?(first: @award.award_begin_date, second: today)

    # award_end_date is before today
    def aed_before_today? = in_order?(first: @award.award_end_date, second: today)

    def in_order?(first:, second:)
      return false if first.blank? || second.blank?

      first < second
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
      puts "\n\n*** pushing enrollment ***"
      puts "attributes: #{attributes}\n\n"

      user_info = self

      @enrollments.push(
        Verification.build(user_profile:, user_info:, **attributes)
      )

      true
    end

    def eval_case_eom
      puts "\n\n*** case_eom"

      if last_day_of_month?
        puts '1 last day of month - continuing'
      else
        puts '1 not last day of month - returning'
      end
      return unless last_day_of_month?

      if abd_before_today? && !aed_before_today?
        puts '2 award beg date is before today && award end date is not before today - continuing'
      else
        puts '2 award beg date is not before today or award end date is not before today - returning'
      end
      return unless abd_before_today? && !aed_before_today?

      puts '***case_eom is true - pushing enrollment ***'
      act_begin =
        if dlc_before_abd? && dlc_before_ldpm?
          puts "  date last certified is b4 award begin date & last day of previous month - assigning award begin date to act begin"
          @award.award_begin_date
        else
          puts "  date last certified is not b4 award begin date & last day of previous month - assigning date last certified to act begin"
          date_last_certified
        end

      push_enrollment(
        award_id: @award.id,
        act_begin:,
        act_end: today,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case_eom
      )

      true
    end

    def flag_open_cert
      puts "\n\nflag_open_cert"
      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_current?
        puts '2 award is current - continuing'
      else
        puts '2 award is not current - returning'
      end
      return unless @award.award_ind_current?

      if @award.award_end_date.present?
        puts '3 award end date is present - returning'
      else
        puts '3 award end date is not present - continuing'
      end
      return if @award.award_end_date.present?

      puts '*** flag_open_cert is true ***'
      @open_cert = true
      @open_cert_award_id = @award.id
      @open_cert_credit_hours = @award.number_hours
      @open_cert_monthly_rate = @award.monthly_rate
      @open_cert_payment_date = @award.payment_date

      true
    end

    def eval_case1a
      puts "\n\ncase1a"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_current?
        puts '2 award is current - continuing'
      else
        puts '2 award is not current - returning'
      end
      return unless @award.award_ind_current?

      if @award.award_end_date.blank?
        puts '3 award end date is blank - returning'
      else
        puts '3 award end date is not blank - continuing'
      end
      return if @award.award_end_date.blank?

      if are_dates_the_same(@award.award_end_date, date_last_certified)
        puts '4 award begin date is the same as date last certified - returning'
      else
        puts '4 award begin date is not the same as date last certified - continuing'
      end
      return if are_dates_the_same(@award.award_end_date, date_last_certified)

      if current_rec_ended?
        puts '5 current record is ended - continuing'
      else
        puts '5 current record is not ended - returning'
      end
      return unless current_rec_ended?

      if ldpm_before_aed? && are_dates_the_same(@award.award_begin_date, @award.award_end_date)
        puts '6 last day of previous month is before award end date && award begin date is the same as award end date - continuing'
      else
        puts '6 last day of previous month is not before award end date || award begin date is not the same as award end date - returning'
      end
      return unless ldpm_before_aed? && are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      puts '*** case1a is true pushing enrollment ***'
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

      true
    end

    def eval_case1b
      puts "\n\ncase1b"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_current?
        puts '2 award is current - continuing'
      else
        puts '2 award is not current - returning'
      end
      return unless @award.award_ind_current?

      if @award.award_end_date.blank?
        puts '3 award end date is blank - returning'
      else
        puts '3 award end date is not blank - continuing'
      end
      return if @award.award_end_date.blank?

      if are_dates_the_same(@award.award_end_date, date_last_certified)
        puts '4 award begin date is the same as date last certified - returning'
      else
        puts '4 award begin date is not the same as date last certified - continuing'
      end
      return if are_dates_the_same(@award.award_end_date, date_last_certified)

      if current_rec_ended?
        puts '5 current record is ended - continuing'
      else
        puts '5 current record is not ended - returning'
      end
      return unless current_rec_ended?

      if ldpm_before_aed? && are_dates_the_same(@award.award_begin_date, @award.award_end_date)
        puts '6 last day of previous month is before award end date && award begin date is the same as award end date - returning'
      else
        puts '6 last day of previous month is not before award end date || award begin date is not the same as award end date - continuing'
      end
      return if ldpm_before_aed? && are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      puts '*** case1b is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: aed_minus1,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case1b
      )

      true
    end

    def eval_case2
      puts "\n\ncase2"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_current?
        puts '2 award is current - continuing'
      else
        puts '2 award is not current - returning'
      end
      return unless @award.award_ind_current?

      if @award.award_end_date.blank?
        puts '3 award end date is blank - returning'
      else
        puts '3 award end date is not blank - continuing'
      end
      return if @award.award_end_date.blank?

      if are_dates_the_same(@award.award_begin_date, date_last_certified)
        puts '4 award begin date is the same as date last certified - returning'
      else
        puts '4 award begin date is not the same as date last certified - continuing'
      end
      return if are_dates_the_same(@award.award_end_date, date_last_certified)

      if current_rec_ended?
        puts '5 current record is ended - returning'
      else
        puts '5 current record is not ended - continuing'
      end
      return if current_rec_ended?

      if ldpm_before_aed? && !ldpm_before_abd?
        puts '6 last day of previous month is before award end date && last day of previous month is not before award begin date - continuing'
      else
        puts '6 last day of previous month is not before award end date || last day of previous month is before award begin date - returning'
      end
      return unless ldpm_before_aed? && !ldpm_before_abd?

      puts '*** case2 is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case2
      )

      true
    end

    def eval_case3
      puts "\n\ncase3"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_current?
        puts '2 award is current - continuing'
      else
        puts '2 award is not current - returning'
      end
      return unless @award.award_ind_current?

      if @award.award_end_date.blank?
        puts '3 award end date is blank - returning'
      else
        puts '3 award end date is not blank - continuing'
      end
      return if @award.award_end_date.blank?

      if are_dates_the_same(@award.award_begin_date, date_last_certified)
        puts '4 award begin date is the same as date last certified - returning'
      else
        puts '4 award begin date is not the same as date last certified - continuing'
      end
      return if are_dates_the_same(@award.award_end_date, date_last_certified)

      if current_rec_ended?
        puts '5 current record is ended - continuing'
      else
        puts '5 current record is not ended - returning'
      end
      return if current_rec_ended?

      if ldpm_before_aed? && !ldpm_before_abd?
        puts '6 last day of previous month is before award end date && last day of previous month is not < award begin date - returning'
      else
        puts '6 last day of previous month is not before award end date || last day of previous month is >= award begin date - continuing'
      end
      return if ldpm_before_aed? && !ldpm_before_abd?

      puts '*** case3 is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: aed_minus1,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case3
      )

      true
    end

    def eval_case4
      puts "\n\ncase4"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_future? && !@supress_future_award
        puts '2 award is future && supress future award is false - continuing'
      else
        puts '2 award is not future || supress future award is true - returning'
      end
      return unless @award.award_ind_future? && !@supress_future_award

      if @open_cert
        puts '3 open cert is true - continuing'
      else
        puts '3 open cert is false - returning'
      end
      return unless @open_cert

      if ldpm_before_abd?
        puts '4 last day of previous month is before award begin date - continuing'
      else
        puts '4 last day of previous month is not before award begin date - returning'
      end
      return unless ldpm_before_abd?

      puts '*** case4 is true pushing enrollment ***'
      push_enrollment(
        award_id: @open_cert_award_id,
        act_begin: date_last_certified,
        act_end: last_day_of_previous_month,
        number_hours: @open_cert_credit_hours,
        monthly_rate: @open_cert_monthly_rate,
        payment_date: @open_cert_payment_date,
        trace: :case4
      )
      clear_cert_variables

      true
    end

    def eval_case5
      puts "\n\ncase5"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_future? && !@supress_future_award
        puts '2 award is future && supress future award is false - continuing'
      else
        puts '2 award is not future || supress future award is true - returning'
      end
      return unless @award.award_ind_future? && !@supress_future_award

      if @open_cert
        puts '3 open cert is true - continuing'
      else
        puts '3 open cert is false - returning'
      end
      return unless @open_cert

      if ldpm_before_abd?
        puts '4 last day of previous month is before award begin date - returning'
      else
        puts '4 last day of previous month is not before award begin date - continuing'
      end
      return if ldpm_before_abd?

      if ldpm_before_aed?
        puts '5 last day of previous month is before award end date - continuing'
      else
        puts '5 last day of previous month is not before award end date - returning'
      end
      return unless ldpm_before_aed?

      puts '*** case5 is true pushing enrollment ***'
      push_enrollment(
        award_id: @open_cert_award_id,
        act_begin: date_last_certified,
        act_end: aed_minus1,
        number_hours: @open_cert_credit_hours,
        monthly_rate: @open_cert_monthly_rate,
        payment_date: @open_cert_payment_date,
        trace: :case5
      )
      clear_cert_variables

      true
    end

    def eval_case6
      puts "\n\ncase6"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_future? && !@supress_future_award
        puts '2 award is future && supress future award is false - continuing'
      else
        puts '2 award is not future || supress future award is true - returning'
      end
      return unless @award.award_ind_future? && !@supress_future_award

      if @open_cert
        puts '3 open cert is true - returning'
      else
        puts '3 open cert is false - continuing'
      end
      return if @open_cert

      if ldpm_before_abd?
        puts '4 last day of previous month is before award begin date - returning'
      else
        puts '4 last day of previous month is not before award begin date - continuing'
      end
      return if ldpm_before_abd?

      if date_last_certified.present?
        puts '5 date last certified is present - returning'
      else
        puts '5 date last certified is not present - continuing'
      end
      return if date_last_certified.present?

      puts '*** case6 is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case6
      )

      true
    end

    def eval_case7
      puts "\n\ncase7"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_future? && !@supress_future_award
        puts '2 award is future && supress future award is false - continuing'
      else
        puts '2 award is not future || supress future award is true - returning'
      end
      return unless @award.award_ind_future? && !@supress_future_award

      if @open_cert
        puts '3 open cert is true - returning'
      else
        puts '3 open cert is false - continuing'
      end
      return if @open_cert

      if ldpm_before_abd?
        puts '4 last day of previous month is before award begin date - returning'
      else
        puts '4 last day of previous month is not before award begin date - continuing'
      end
      return if ldpm_before_abd?

      if date_last_certified.blank?
        puts '5 date last certified is blank - returning'
      else
        puts '5 date last certified is not blank - continuing'
      end
      return if date_last_certified.blank?

      if ldpm_before_aed?
        puts '6 last day of previous month is before award end date - continuing'
      else
        puts '6 last day of previous month is not before award end date - returning'
      end
      return unless ldpm_before_aed?

      puts '*** case7 is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: last_day_of_previous_month,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case7
      )

      true
    end

    def eval_case8
      puts "\n\ncase8"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - continuing'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - returning'
      end
      return unless dlc_before_ldpm? || date_last_certified.blank?

      if @award.award_ind_future? && !@supress_future_award
        puts '2 award is future && supress future award is false - continuing'
      else
        puts '2 award is not future || supress future award is true - returning'
      end
      return unless @award.award_ind_future? && !@supress_future_award

      if @open_cert
        puts '3 open cert is true - returning'
      else
        puts '3 open cert is false - continuing'
      end
      return if @open_cert

      if ldpm_before_abd?
        puts '4 last day of previous month is before award begin date - returning'
      else
        puts '4 last day of previous month is not before award begin date - continuing'
      end
      return if ldpm_before_abd?

      if date_last_certified.blank?
        puts '5 date last certified is blank - returning'
      else
        puts '5 date last certified is not blank - continuing'
      end
      return if date_last_certified.blank?

      if ldpm_before_aed?
        puts '6 last day of previous month is before award end date - returning'
      else
        puts '6 last day of previous month is not before award end date - continuing'
      end
      return if ldpm_before_aed?

      puts '*** case8 is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: @award.award_begin_date,
        act_end: aed_minus1,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case8
      )

      true
    end

    def eval_case9
      puts "\n\ncase9"

      if dlc_before_ldpm? || date_last_certified.blank?
        puts '1 date last certified is before last day of previous month or is blank - returning'
      else
        puts '1 date last certified is not before last day of previous month and is not blank - continuing'
      end
      return if dlc_before_ldpm? || date_last_certified.blank?

      if aed_before_today?
        puts '2 award end date is before today - continuing'
      else
        puts '2 award end date is not before today - returning'
      end
      return unless aed_before_today?

      if are_dates_the_same(@award.award_begin_date, @award.award_end_date)
        puts '3 award begin date is the same as award end date - continuing'
      else
        puts '3 award begin date is not the same as award end date - returning'
      end
      return unless are_dates_the_same(@award.award_begin_date, @award.award_end_date)

      puts '*** case9 is true pushing enrollment ***'
      push_enrollment(
        award_id: @award.id,
        act_begin: date_last_certified,
        act_end: aed_minus1,
        number_hours: @award.number_hours,
        monthly_rate: @award.monthly_rate,
        payment_date: @award.payment_date,
        trace: :case9
      )

      true
    end
  end
end
