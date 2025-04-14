# frozen_string_literal: true

# This is included from UserInfo

module Vye
  module NeedsEnrollmentVerification
    def enrollments
      return [] if queued_verifications?
      return @enrollments if defined?(@enrollments)

      setup

      puts "\n*** processing awards current date is #{today}"
      awards.each_with_index do |award, idx|
        # cur_award_ind is passed in from the feed, we do not determine it.
        puts "\n*** processing award #{idx + 1} of #{awards.size} ***"
        @award = award
        @award_begin_date = award.award_begin_date
        @award_end_date = award.award_end_date

        puts "award_begin_date: #{award_begin_date}"
        puts "award_end_date:   #{award_end_date}"
        puts "prev cert date:   #{previous_certification_date}"

        # open certificates are not eligible for verification
        next if flag_open_cert(idx, awards.size - 1)

        # this helps to see what's going on with the order of the relevant dates
        puts_the_order_of_the_criteria_dates

        # past awards have already been paid. Do not create a pending verification
        if award_end_date <= previous_certification_date
          puts "award_end_date <= previous_certification_date - returning"
        else
          puts "previous_certification_date < award_end_date - continuing"
        end
        next if award_end_date <= previous_certification_date

        # no pending verfications for future awards
        next if eval_future_award

        next if eval_case_eom

        # rubocop:disable Style/EmptyCaseCondition
        case
        # abd <=  dlc  <  aed  <  ldpm <  rd   [dlc, aed - 1 day]
        when case1  then push_enrollment(:case1)

        # abd <=  dlc  <  ldpm <= aed <=  rd   [dlc, aed - 1 day]
        # 3/1     3/15    3/31    3/31    4/15 [3/15, 3/30]
        # 3/1     3/15    3/31    4/1     4/15 [3/15, 3/31]
        when case2  then push_enrollment(:case2)

        # abd <=  dlc  <  ldpm <  rd  <   aed  [dlc, ldpm]
        when case3  then push_enrollment(:case3)

        # abd <=  ldpm <= dlc  <  aed <=  rd   [dlc, aed - 1 day]
        when case4  then push_enrollment(:case4)

        # If aed was ldpm, this would be an eom case
        # dlc <   abd  <= aed  <  ldpm <  rd   [abd, aed - 1 day]
        when case5  then push_enrollment(:case5)

        # dlc <   abd  <= ldpm <= aed  <= rd   [abd, aed - 1 day] or [abd, aed] if abd == aed
        when case6  then push_enrollment(:case6)

        # dlc <   abd  <= ldpm <  rd   <  aed  [abd, ldpm]
        when case7  then push_enrollment(:case7)

        # dlc <   ldpm <= abd <=  aed <=  rd   [abd, aed - 1 day] or [abd, aed] if abd == aed
        # 3/1     3/31    3/31    3/31    4/15
        # 3/1     3/31    3/31    4/1     4/15
        when case8  then push_enrollment(:case8)

        # ldpm <	abd	<=	dlc < 	aed	<=	rd   [dlc, aed - 1 day] or [abd, aed] if abd == aed
        # 3/31    4/1     4/1     4/15    4/15
        when case9  then push_enrollment(:case9)

        # ldpm <= dlc	<		abd	<=	aed	<=	rd   [abd, aed - 1 day] or [abd, aed] if abd == aed
        when case10 then push_enrollment(:case10)
        else next
        end
      end
      # rubocop:enable Style/EmptyCaseCondition

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
      puts "\nflag_open_cert"

      puts "award end date is present, award is not open" if award_end_date.present?
      return false if award_end_date.present?

      if idx.eql?(last_idx) && award_end_date.blank?
        puts "award end date is missing and this is the last award in the list, award is open"
      else
        puts "not the last award in the list or award end date is not missing, continuing"
      end
      return true if idx.eql?(last_idx) && award_end_date.blank?

      # Award end date is missing and this is not the last award in the list
      # the award end date is implied to be the next award's begin date - 1 day.
      puts 'next award begin date - 1 day to award end date, award is not open'
      next_award = awards[idx + 1]
      @award_end_date = (next_award.award_begin_date - 1.day)

      false
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

    def sort_keys_by_date_ascending(date_hash)
      date_hash.sort_by { |_, date| date }.to_h
    end

    def eval_future_award
      puts "\n*** case_future"

      if award_begin_date.present? && award_begin_date > today
        puts "1 run date #{today} < award begin date #{award_begin_date}, future award"
      end
      return true if award_begin_date.present? && award_begin_date > today

      # last day of the month is an exception. We can have an award date after the end of the month
      # in which case we will certify up to the end of the month. Don't consider it a future award.
      if end_of_month.eql?(today)
        puts "run date #{today} is the end of month #{end_of_month}, not a future award"
      end
      return false if end_of_month.eql?(today)

      if previous_certification_date > last_day_of_previous_month &&
         award_begin_date <= last_day_of_previous_month &&
         today < award_end_date
        puts '2 awd beg dt <= ldpm < last cert dt < today < awd end dt, future award'
        return true
      end

      if previous_certification_date <= last_day_of_previous_month &&
         last_day_of_previous_month < award_begin_date && award_begin_date <= today &&
         today < award_end_date
        puts '3 last cert dt <= ldpm < awd beg dt <= today < awd end dt, future award'
        return true
      end

      if last_day_of_previous_month < award_begin_date &&
         award_begin_date <= previous_certification_date && previous_certification_date < today &&
         today < award_end_date
        puts '4 ldpm < awd beg dt <= last cert dt < today < awd end dt, future award'
        return true
      end

      if last_day_of_previous_month < previous_certification_date &&
         previous_certification_date < award_begin_date &&
         award_begin_date <= today &&
         today < award_end_date
        puts '5 ldpm < last cert dt < awd beg dt <= today < awd end dt, future award'
        return true
      end

      puts '6 not future award - continuing'
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
      return unless today.eql?(end_of_month)

      if today.between?(award_begin_date, award_end_date)
        puts '  2 award beg date < today <= award end date - continuing'
      else
        puts '  2 award beg date >= today or award end date < today - returning'
      end
      return unless today.between?(award_begin_date, award_end_date)

      puts '  award is case_eom'
      push_enrollment(:case_eom)

      true
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
          award_begin_date.eql?(award_end_date) ? award_end_date : aed_minus1
        when :case_eom
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
      puts "attributes: #{@enrollments.last.attributes}\n\n"
    end

    def case1
      puts "\ncase1"
      if award_begin_date <= previous_certification_date && previous_certification_date < award_end_date &&
         award_end_date < last_day_of_previous_month && last_day_of_previous_month < today
        puts '  abd <=  *dlc  <  aed*  <  ldpm <  rd'
        true
      end
    end

    def case2
      puts "case2"
      if award_begin_date <= previous_certification_date && previous_certification_date < last_day_of_previous_month &&
         last_day_of_previous_month <= award_end_date && award_end_date <= today
        puts '  abd <=  *dlc  <  ldpm <=  aed* <=  rd'
        true
      end
    end

    def case3
      puts "case3"
      if award_begin_date <= previous_certification_date && previous_certification_date < last_day_of_previous_month &&
         last_day_of_previous_month < today && today < award_end_date
        puts '  abd <=  *dlc  <  ldpm* <  rd  <   aed'
        true
      end
    end

    def case4
      puts "case4"
      if award_begin_date <= last_day_of_previous_month && last_day_of_previous_month <= previous_certification_date &&
         previous_certification_date < award_end_date && award_end_date <= today
        puts '  abd <=  *ldpm < dlc  <  aed* <=  rd'
        true
      end
    end

    def case5
      puts "case5"
      if previous_certification_date < award_begin_date && award_begin_date <= award_end_date &&
         award_end_date < last_day_of_previous_month && last_day_of_previous_month < today
        puts '  dlc <   *abd  <= aed*  <= ldpm <  rd'
        true
      end
    end

    def case6
      puts "case6"
      if previous_certification_date < award_begin_date && award_begin_date <= last_day_of_previous_month &&
         last_day_of_previous_month <= award_end_date && award_end_date <= today
        puts '  dlc <   *abd  <= ldpm <=  aed*  <= rd'
        true
      end
    end

    def case7
      puts "case7"
      if previous_certification_date < award_begin_date && award_begin_date <= last_day_of_previous_month &&
         last_day_of_previous_month < today && today < award_end_date
        puts '  dlc <   *abd  <= ldpm* <  rd   <  aed'
        true
      end
    end

    def case8
      puts "case8"
      if previous_certification_date < last_day_of_previous_month && last_day_of_previous_month <= award_begin_date &&
         award_begin_date <= award_end_date && award_end_date <= today
        puts '  dlc <   ldpm <=  *abd <=  aed* <=  rd'
        true
      end
    end

    def case9
      puts "case9"
      if last_day_of_previous_month < award_begin_date && award_begin_date <= previous_certification_date &&
         previous_certification_date < award_end_date && award_end_date <= today
        puts '  ldpm <	abd	<=	*dlc < 	aed*	<=	rd'
        true
      end
    end

    def case10
      puts "case10"
      if last_day_of_previous_month <= previous_certification_date && previous_certification_date < award_begin_date &&
         award_begin_date <= award_end_date && award_end_date <= today
        puts '  ldpm <= dlc	<		*abd	<=	aed*	<=	rd'
        true
      end
    end
  end
end
