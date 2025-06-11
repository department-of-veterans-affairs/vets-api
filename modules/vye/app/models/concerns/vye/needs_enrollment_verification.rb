# frozen_string_literal: true

# *** refactor, abd will always be < aed

# This is included from UserInfo

# rubocop:disable Rails/Output
module Vye
  module NeedsEnrollmentVerification
    def enrollments
      return [] if queued_verifications?
      return @enrollments if defined?(@enrollments)

      setup

      # notes on rules for pending verifications
      # award beg date = abd
      # award end date = aed
      # date last cert = dlc
      # last day prior month = ldpm
      # run date = rd
      # aed is always >= dlc
      # abd is always <  rd
      # abd is always <  aed
      # dlc is always <  rd or blank
      #                                           act  act
      #                                           beg  end
      #  1) abd <=  dlc  <  aed  <  ldpm <  rd   [dlc, aed - 1 day]
      #     2/28    3/1     3/30    3/31    4/5   3/1  3/29
      #     3/1     3/1     3/2     3/31    4/5   3/1  3/1
      #     3/1     3/1     3/30    3/31    4/5   3/1  3/29
      #
      #  2) abd <=  dlc  <  ldpm <= aed <=  rd   [dlc, aed - 1 day] **
      #     2/28    3/1     3/31    3/31    4/15  3/1  3/30
      #     2/28    3/1     3/31    4/1     4/15  3/1  3/31
      #     2/28    3/1     3/31    4/3     4/15  3/1  4/2
      #     3/1     3/1     3/31    3/31    4/15  3/1  3/30
      #     3/1     3/1     3/31    4/3     4/15  3/1  4/2
      #     3/1     3/15    3/31    4/3     4/15  3/15 4/2
      #     3/1     3/30    3/31    4/15    4/15  3/30 4/14
      #
      #  3) abd <=  dlc  <  ldpm <  rd  <   aed  [dlc, ldpm]
      #     2/28    3/1     3/31    4/2     4/15  3/1  3/31
      #     3/1     3/1     3/31    4/2     4/15  3/1  3/31
      #     3/1     3/30    3/31    4/2     4/15  3/30 3/31
      #
      #  4) abd <=  ldpm <= dlc  <  aed <=  rd   [dlc, aed - 1 day] **
      #     3/30    3/31    3/31    4/1    4/15   3/31 3/31
      #     3/31    3/31    3/31    4/1    4/15   3/31 3/31
      #     3/31    3/31    3/31    4/2    4/15   3/31 4/1
      #     3/31    3/31    3/31    4/15   4/15   3/31 4/14i
      #     3/31    3/31    4/1     4/2    4/15   4/1  4/1
      #     3/31    3/31    4/1     4/15   4/15   4/1  4/14
      #
      #     abd <=  ldpm <= dlc  <  rd  <   aed  no pending verification
      #                     4/2     4/15    4/30
      #
      #  5) dlc <   abd  <  aed  <  ldpm <  rd   [abd, aed - 1 day]
      #     3/1     3/2     3/30    3/31    4/15  3/2  3/29
      #
      #  6) dlc <   abd  <  ldpm <= aed  <= rd   [abd, aed - 1 day] or
      #     dlc <   abd  <= ldpm <  aed  <= rd   [abd, aed - 1 day]
      #     3/1     3/30    3/31    3/31    4/15  3/30 3/31
      #     3/1     3/2     3/31    4/1     4/15  3/2  3/31
      #     3/1     3/31    3/31    4/1     4/15  3/31 3/31
      #     3/1     3/31    3/31    4/1     4/15  3/31 3/31
      #     3/1     3/31    3/31    4/2     4/15  3/31 4/1
      #     3/1     3/31    3/31    4/15    4/15  3/31 4/14
      #
      #  7) dlc <   abd  <= ldpm <  rd   <  aed  [abd, ldpm]
      #     3/1     3/2     3/31    4/2     4/3   3/2  3/31
      #     3/1     3/30    3/31    4/2     4/3   3/30 3/31
      #     3/1     3/31    3/31    4/2     4/3   3/31 3/31
      #
      #  8) dlc <   ldpm <  abd <   aed <=  rd   [abd, aed - 1 day]
      #     3/30    3/31    4/1     4/2     4/15  4/1  4/1
      #     3/30    3/31    4/1     4/15    4/15  4/1  4/14
      #
      #     dlc <   ldpm <  abd     rd      aed  no pending verification **
      #     3/1     3/31    4/2    4/15    6/15
      #
      #  9) ldpm <	abd	<=	dlc < 	aed	<=	rd   [dlc, aed - 1 day]
      #     3/31    4/1     4/1     4/3     4/15  4/1  4/2
      #     3/31    4/1     4/2     4/3     4/15  4/2  4/2
      #     3/31    4/1     4/2     4/15    4/15  4/2  4/14
      #
      #     ldpm <	abd	<=	dlc	<	  rd	<		aed  no pending verification
      #     3/31    4/1     4/1     4/14    4/15
      #
      # 10) ldpm <= dlc	<		abd	< 	aed	<=	rd   [abd, aed - 1 day]
      #     3/31    3/31    4/2     4/3     4/15  4/2  4/2
      #     3/31    4/1     4/2     4/15    4/15  4/2  4/14
      #
      #     ldpm <=	dlc	<		abd	<=	rd	<		aed  no pending verification
      #      3/31   4/1     4/1     4/15    6/15

      puts "\n*** processing awards current date is #{today}"
      awards.each_with_index do |award, idx|
        # cur_award_ind is passed in from the feed, we do not determine it.
        puts "\n*** processing award #{idx + 1} of #{awards.size} ***"
        @award = award
        @award_begin_date = award.award_begin_date
        @award_end_date = award.award_end_date

        puts "awd beg dt: #{award_begin_date} awd end dt: #{award_end_date} pv crt dt: #{previous_certification_date}"

        # open certificates are not eligible for verification
        next if flag_open_cert(idx, awards.size - 1)

        # this helps to see what's going on with the order of the relevant dates
        puts_the_order_of_the_criteria_dates

        # past awards have already been paid. Do not create a pending verification
        puts 'checking for past award'
        if award_end_date <= previous_certification_date
          puts '  award_end_date <= previous_certification_date - past award - returning'
        else
          puts '  previous_certification_date < award_end_date - continuing'
        end
        next if award_end_date <= previous_certification_date

        # no pending verfications for future awards
        next if eval_future_award

        # TODO: Run a batch & determine which cases are the most frequent and refactor
        #       the order of the methods accordingly
        # --------------------------------------------------------------------------------
        # Original cases and what the act_begin & act_end should be for each case
        # --------------------------------------------------------------------------------
        # 01 abd  <= dlc  <  aed  <= ldpm <  rd		dlc, aed minus 1 day
        # 02 abd  <= dlc  <  ldpm <  aed  <= rd		dlc, aed minus 1 day
        # 04 abd  <= ldpm <  dlc  <  aed  <= rd   dlc, aed minus 1 day
        # --------------------------------------------------------------------------------
        # 05 dlc   < abd  < aed  <= ldpm <  rd		abd, aed minus 1 day or aed if abd = aed
        # 06 dlc   < abd  <= ldpm < aed  <= rd		abd, aed minus 1 day
        # 08 dlc  <= ldpm <  abd  < aed  <= rd		abd, aed minus 1 day or aed if abd = aed
        # 09 dlc  <= ldpm <  abd  <= rd   = aed	  abd, aed minus 1 day or aed if abd = aed
        # 10 ldpm  < dlc  <= abd  <  aed  <= rd  	abd, aed minus 1 day or aed if abd = aed
        # --------------------------------------------------------------------------------
        # 03 abd  <= dlc  <  ldpm <  rd   <  aed  dlc, ldpm
        # --------------------------------------------------------------------------------
        # 07 dlc   < abd  <= ldpm <  rd   <  aed	abd, ldpm
        # --------------------------------------------------------------------------------

        trace = eval_case_eom ||
                act_beg_is_dlc_and_act_end_is_ldpm ||
                act_beg_is_dlc_and_act_end_is_aed  ||
                act_beg_is_abd_and_act_end_is_ldpm ||
                act_beg_is_abd_and_act_end_is_aed

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

    # Helper method to check if a date is in the same month or later than today
    def date_in_same_month_or_later?(date)
      return false if date.blank?

      date.beginning_of_month >= today.beginning_of_month
    end

    # We do not make pending verifications for awards if the award_end_date is blank (nil)
    # Determine this and return true/false
    def flag_open_cert(idx, last_idx)
      puts "\nflag_open_cert"

      puts '  award_begin_date is nil - award is open' if award_begin_date.blank?
      return true if award_begin_date.blank?

      puts '  award end date is present, award is not open' if award_end_date.present?
      return false if award_end_date.present?

      if idx.eql?(last_idx) && award_end_date.blank?
        puts '  award end date is missing and this is the last award in the list, award is open'
      else
        puts '  not the last award in the list or award end date is not missing, continuing'
      end
      return true if idx.eql?(last_idx) && award_end_date.blank?

      # Award end date is missing and this is not the last award in the list
      # the award end date is implied to be the next award's begin date - 1 day.
      next_award = awards[idx + 1]
      implied_end_date = (next_award.award_begin_date - 1.day)

      # Check if the implied_end_date is in the same month or later than run date
      if date_in_same_month_or_later?(implied_end_date)
        # Additional check: if the award begin date is in a previous month,
        # we should NOT treat it as an open cert, but instead create a verification
        # using the first day of current month as the end date (so cert through date = last day of previous month)
        if date_in_same_month_or_later?(award_begin_date)
          # Exception: If user is verifying on the very last day of the month,
          # allow them to verify through that date even if award begin date is in same month
          if today.eql?(end_of_month)
            puts '  verifying on last day of month - allowing verification through today despite award begin date being in same month'
            @award_end_date = today + 1.day # First day of next month (No Pay Date) so cert thru date = today (aed-1)
            return false
          else
            puts '  implied end date is in same month or later than run date - treating as open cert'
            return true # Treat as open cert when implied date is in current month or later AND award begin date is not in previous month
          end
        else
          puts '  implied end date is in current month or later, but award begin date is in previous month - using first day of current month as end date'
          @award_end_date = today.beginning_of_month
          return false
        end
      else
        puts '  setting next award begin date - 1 day to award end date, award is not open'
        @award_end_date = implied_end_date
      end

      false
    end

    def sort_keys_by_date_ascending(date_hash)
      # Filter out nil values before sorting
      date_hash.compact.sort_by { |_, date| date }.to_h
    end

    def puts_the_order_of_the_criteria_dates
      puts "\n*** sorting the criteria dates ***"

      dates = {
        previous_certification_date:, last_day_of_previous_month:,
        award_begin_date:, award_end_date:, run_date: today
      }

      sort_keys_by_date_ascending(dates).each { |key, value| printf "#{key}: #{value} | " }
      puts "\n\n"
    end

    def eval_future_award
      puts "\n*** case_future"

      if award_begin_date.present? && award_begin_date > today
        puts "  1 run date #{today} < award begin date #{award_begin_date}, future award"
      end
      return true if award_begin_date.present? && award_begin_date > today

      # last day of the month is an exception. We can have an award date after the end of the month
      # in which case we will certify up to the end of the month. Don't consider it a future award.
      puts "  run date #{today} is the end of month #{end_of_month}, not a future award" if end_of_month.eql?(today)
      return false if end_of_month.eql?(today)

      if previous_certification_date > last_day_of_previous_month &&
         award_begin_date <= last_day_of_previous_month &&
         today < award_end_date
        puts '  2 awd beg dt <= ldpm < last cert dt < today < awd end dt, future award'
        return true
      end

      if previous_certification_date <= last_day_of_previous_month &&
         last_day_of_previous_month < award_begin_date && award_begin_date <= today &&
         today < award_end_date
        puts '  3 last cert dt <= ldpm < awd beg dt <= today < awd end dt, future award'
        return true
      end

      if last_day_of_previous_month < award_begin_date &&
         award_begin_date <= previous_certification_date && previous_certification_date < today &&
         today < award_end_date
        puts '  4 ldpm < awd beg dt <= last cert dt < today < awd end dt, future award'
        return true
      end

      if last_day_of_previous_month < previous_certification_date &&
         previous_certification_date < award_begin_date &&
         award_begin_date <= today &&
         today < award_end_date
        puts '  5 ldpm < last cert dt < awd beg dt <= today < awd end dt, future award'
        return true
      end

      puts '  6 not future award - continuing'
      false
    end

    def eval_case_eom
      puts "\n*** case_eom ***"
      puts "  award beg: #{award_begin_date} today: #{today} award end: #{award_end_date}"

      if today.eql?(end_of_month)
        puts '  1 last day of month - continuing'
      else
        puts '  1 not last day of month - returning'
      end
      return nil unless today.eql?(end_of_month)

      if today.between?(award_begin_date, award_end_date)
        puts '  2 award beg date < today <= award end date - continuing'
      else
        puts '  2 award beg date >= today or award end date < today - returning'
      end
      return nil unless today.between?(award_begin_date, award_end_date)

      puts '  award is case_eom'
      :case_eom
    end

    def aed_minus1
      return nil if award_end_date.blank?

      award_end_date - 1.day
    end

    def push_enrollment(trace)
      puts "\n*** pushing enrollment for #{trace} ***"

      award_id = @award.id
      number_hours = @award.number_hours
      monthly_rate = @award.monthly_rate
      payment_date = @award.payment_date

      act_begin =
        case trace
        when :case5, :case6, :case7, :case8, :case10
          award_begin_date
        when :case_eom
          [award_begin_date, previous_certification_date].max
        else previous_certification_date
        end

      act_end =
        case trace
        when :case1, :case2, :case4, :case5, :case6, :case8, :case9, :case10
          aed_minus1
        when :case_eom
          if award_begin_date < award_end_date && award_end_date.eql?(today)
            aed_minus1
          else
            today
          end
        else last_day_of_previous_month
        end

      user_info = self

      @enrollments.push(
        Verification.build(
          user_profile:, user_info:, award_id:, number_hours:, monthly_rate:,
          payment_date:, act_begin:, act_end:, trace:
        )
      )
      puts "attributes: #{@enrollments.last.attributes}\n\n"
    end

    def act_beg_is_abd_and_act_end_is_aed
      puts "\n*** act_beg_is_aed_and_act_end_is_aed ***"

      if previous_certification_date < award_begin_date && award_begin_date < award_end_date &&
         award_end_date < last_day_of_previous_month && last_day_of_previous_month < today
        puts '  dlc <   *abd  < aed*  <= ldpm <  rd : case5'
        return :case5
      end

      if previous_certification_date < award_begin_date &&
         ((award_begin_date <= last_day_of_previous_month && last_day_of_previous_month <  award_end_date) ||
          (award_begin_date <  last_day_of_previous_month && last_day_of_previous_month <= award_end_date)) &&
         award_end_date <= today
        puts '  dlc <   *abd  <= ldpm <= aed*  <= rd : case6'
        return :case6
      end

      if previous_certification_date < last_day_of_previous_month && last_day_of_previous_month <= award_begin_date &&
         award_begin_date < award_end_date && award_end_date <= today
        puts '  dlc <   ldpm <=  *abd <  aed* <=  rd : case8'
        return :case8
      end

      if last_day_of_previous_month < award_begin_date && award_begin_date <= previous_certification_date &&
         previous_certification_date < award_end_date && award_end_date <= today
        puts '  ldpm <	abd	<=	*dlc < 	aed*	<=	rd : case9'
        return :case9
      end

      if last_day_of_previous_month <= previous_certification_date && previous_certification_date < award_begin_date &&
         award_begin_date < award_end_date && award_end_date <= today
        puts '  ldpm <= dlc	<		*abd	<	aed*	<=	rd : case10'
        return :case10
      end

      nil
    end

    def act_beg_is_dlc_and_act_end_is_aed
      puts "\n*** act_beg_is_dlc_and_act_end_is_aed ***"

      if award_begin_date <= previous_certification_date && previous_certification_date < award_end_date &&
         award_end_date < last_day_of_previous_month && last_day_of_previous_month < today
        puts '  abd <=  *dlc  <  aed*  <  ldpm <  rd : case1'
        return :case1
      end

      if award_begin_date <= previous_certification_date && previous_certification_date < last_day_of_previous_month &&
         last_day_of_previous_month <= award_end_date && award_end_date <= today
        puts '  abd <=  *dlc  <  ldpm <=  aed* <=  rd : case2'
        return :case2
      end

      if award_begin_date <= last_day_of_previous_month && last_day_of_previous_month <= previous_certification_date &&
         previous_certification_date < award_end_date && award_end_date <= today
        puts '  abd <=  *ldpm < dlc  <  aed* <=  rd : case4'
        return :case4
      end

      nil
    end

    def act_beg_is_dlc_and_act_end_is_ldpm
      puts "\n*** act_beg_is_dlc_and_act_end_is_ldpm ***"

      if award_begin_date <= previous_certification_date && previous_certification_date < last_day_of_previous_month &&
         last_day_of_previous_month < today && today < award_end_date
        puts '  abd <=  *dlc  <  ldpm* <  rd  <   aed : case3'
        return :case3
      end

      nil
    end

    def act_beg_is_abd_and_act_end_is_ldpm
      puts "\n*** act_beg_is_abd_and_act_end_is_ldpm ***"

      if previous_certification_date < award_begin_date && award_begin_date <= last_day_of_previous_month &&
         last_day_of_previous_month < today && today < award_end_date
        puts '  dlc <   *abd  <= ldpm* <  rd   <  aed : case7'
        return :case7
      end

      nil
    end
  end
end
# rubocop:enable Rails/Output