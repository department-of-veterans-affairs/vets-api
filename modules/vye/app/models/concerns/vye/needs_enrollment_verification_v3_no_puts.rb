# frozen_string_literal: true

# This is included from UserInfo

module Vye
  module NeedsEnrollmentVerificationV2
    def enrollments
      return [] if queued_verifications?
      return @enrollments if defined?(@enrollments)

      setup

      awards.each_with_index do |award, idx|
        @award = award
        @award_begin_date = award.award_begin_date
        @award_end_date = award.award_end_date

        # open certificates are not eligible for verification
        next if flag_open_cert(idx, awards.size - 1)

        # past awards have already been paid. Do not create a pending verification
        next if award_end_date <= previous_certification_date

        # no pending verfications for future awards
        next if eval_future_award

        trace = eval_case_eom ||
                act_beg_is_abd_and_act_end_is_aed ||
                act_beg_is_dlc_and_act_end_is_aed ||
                act_beg_is_dlc_and_act_end_is_ldpm ||
                act_beg_is_abd_and_act_end_is_ldpm

        push_enrollment(trace) if trace
      end

      @enrollments
    end

    alias pending_verifications enrollments

    private

    attr_accessor :award, :award_begin_date, :award_end_date
    attr_reader :today, :last_day_of_previous_month, :end_of_month, :previous_certification_date

    def setup
      @today ||= Time.zone.today
      @last_day_of_previous_month ||= @today.beginning_of_month - 1.day
      @end_of_month ||= @today.end_of_month

      # if the user has never certified, i.e. the first time, it will be nil. Set it
      # to the beginning of ruby time for comparison purposes
      @previous_certification_date = date_last_certified || Date.new(-4712, 1, 1)
      @enrollments = []
    end

    # We do not make pending verifications for awards if the award_end_date is blank (nil)
    # Determine this and return true/false
    def flag_open_cert(idx, last_idx)
      return false if award_end_date.present?
      return true if idx.eql?(last_idx) && award_end_date.blank?

      # Award end date is missing and this is not the last award in the list
      # the award end date is implied to be the next award's begin date - 1 day.
      next_award = awards[idx + 1]
      @award_end_date = (next_award.award_begin_date - 1.day)

      false
    end

    def eval_future_award
      return true if award_begin_date.present? && award_begin_date > today

      # last day of the month is an exception. We can have an award date after the end of the month
      # in which case we will certify up to the end of the month. Don't consider it a future award.
      return false if end_of_month.eql?(today)

      if previous_certification_date > last_day_of_previous_month &&
         award_begin_date <= last_day_of_previous_month &&
         today < award_end_date
        return true
      end

      if previous_certification_date <= last_day_of_previous_month &&
         last_day_of_previous_month < award_begin_date && award_begin_date <= today &&
         today < award_end_date
        return true
      end

      if last_day_of_previous_month < award_begin_date &&
         award_begin_date <= previous_certification_date && previous_certification_date < today &&
         today < award_end_date
        return true
      end

      if last_day_of_previous_month < previous_certification_date &&
         previous_certification_date < award_begin_date &&
         award_begin_date <= today &&
         today < award_end_date
        return true
      end

      false
    end

    def eval_case_eom
      return nil unless today.eql?(end_of_month)
      return nil unless today.between?(award_begin_date, award_end_date)

      'case_eom'
    end

    def aed_minus1
      return nil if award_end_date.blank?

      award_end_date - 1.day
    end

    def push_enrollment(trace)
      award_id = @award.id
      number_hours = @award.number_hours
      monthly_rate = @award.monthly_rate
      payment_date = @award.payment_date

      act_begin =
        case trace
        when 'case5', 'case6', 'case7', 'case8', 'case10'
          award_begin_date
        when 'case_eom'
          [award_begin_date, previous_certification_date].max
        else previous_certification_date
        end

      act_end =
        case trace
        when 'case1', 'case2', 'case4', 'case5', 'case6', 'case8', 'case9', 'case10'
          award_begin_date.eql?(award_end_date) ? award_end_date : aed_minus1
        when 'case_eom'
          award_begin_date < award_end_date && award_end_date.eql?(today) ? aed_minus1 : today
        else last_day_of_previous_month
        end

      user_info = self

      @enrollments.push(
        Verification.build(
          user_profile:, user_info:, award_id:, number_hours:, monthly_rate:,
          payment_date:, act_begin:, act_end:, trace:
        )
      )
    end

    def act_beg_is_abd_and_act_end_is_aed
      if previous_certification_date < award_begin_date && award_begin_date <= award_end_date &&
         award_end_date < last_day_of_previous_month && last_day_of_previous_month < today
        return 'case5'
      end

      if previous_certification_date < award_begin_date && award_begin_date <= last_day_of_previous_month &&
         last_day_of_previous_month <= award_end_date && award_end_date <= today
        return 'case6'
      end

      if previous_certification_date < last_day_of_previous_month && last_day_of_previous_month <= award_begin_date &&
         award_begin_date <= award_end_date && award_end_date <= today
        return 'case8'
      end

      if last_day_of_previous_month < award_begin_date && award_begin_date <= previous_certification_date &&
         previous_certification_date < award_end_date && award_end_date <= today
        return 'case9'
      end

      if last_day_of_previous_month <= previous_certification_date && previous_certification_date < award_begin_date &&
         award_begin_date <= award_end_date && award_end_date <= today
        return 'case10'
      end

      nil
    end

    def act_beg_is_dlc_and_act_end_is_aed
      if award_begin_date <= previous_certification_date && previous_certification_date < award_end_date &&
         award_end_date < last_day_of_previous_month && last_day_of_previous_month < today
        return 'case1'
      end

      if award_begin_date <= previous_certification_date && previous_certification_date < last_day_of_previous_month &&
         last_day_of_previous_month <= award_end_date && award_end_date <= today
        return 'case2'
      end

      if award_begin_date <= last_day_of_previous_month && last_day_of_previous_month <= previous_certification_date &&
         previous_certification_date < award_end_date && award_end_date <= today
        return 'case4'
      end

      nil
    end

    def act_beg_is_dlc_and_act_end_is_ldpm
      if award_begin_date <= previous_certification_date && previous_certification_date < last_day_of_previous_month &&
         last_day_of_previous_month < today && today < award_end_date
        return 'case3'
      end

      nil
    end

    def act_beg_is_abd_and_act_end_is_ldpm
      if previous_certification_date < award_begin_date && award_begin_date <= last_day_of_previous_month &&
         last_day_of_previous_month < today && today < award_end_date
        return 'case7'
      end

      nil
    end
  end
end
