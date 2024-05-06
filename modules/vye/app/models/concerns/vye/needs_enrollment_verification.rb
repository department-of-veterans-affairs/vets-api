# rubocop:disable all

module Vye
  module NeedsEnrollmentVerification
    private

    attr_writer :award

    attr_reader(
      :today, :award,
      :award_begin_date, :award_end_date, :award_end_date_minus_one_day, :current_award_indicator, :number_of_hours,
      :caseAwardID, :caseStartDate, :caseEndDate, :caseCredits, :caseTrace
    )

    def compareDateToNowReturnBoolean(date)
      date < self.today
    end

    def compareTwoDatesReturnBoolean(date1, date2)
      date1 < date2
    end

    def compareTwoDatesDate1GreaterThanDate2ReturnBoolean(date1, date2)
      date1 > date2
    end

    def last_day_of_previous_month
      self.today.beginning_of_month - 1.day
    end

    def current_rec_ended
      @current_award_indicator == "C" && compareTwoDatesReturnBoolean(@award_end_date, self.today)
    end

    def areDatesTheSame(date1, date2)
      date1 == date2
    end

    # date_last_certified is before award_begin_date
    def dlc_before_abd?
      self.compareTwoDatesReturnBoolean(self.date_last_certified, self.award.award_begin_date)
    end

    # date_last_certified is before last day of previous month
    def dlc_before_ldpm?
      self.compareTwoDatesReturnBoolean(self.date_last_certified, self.last_day_of_previous_month)
    end

    # last day of previous month is before award_begin_date
    def ldpm_before_abd?
      self.compareTwoDatesReturnBoolean(self.last_day_of_previous_month, self.award.award_begin_date)
    end

    # last day of previous month is before award_end_date
    def ldpm_before_aed?
      self.compareTwoDatesReturnBoolean(self.last_day_of_previous_month, self.award.award_end_date)
    end

    # award_end_date is before today
    def aed_before_today?
      self.compareDateToNowReturnBoolean(self.award.award_end_date)
    end

    def last_day_of_month?
      self.today == self.today.end_of_month
    end
    
    def setup
      @today = Date.today
      @enrollments = []
      @supressFutureAward = false
      self.clearCaseVariable
      self.clearCertVariables
    end

    def extract_data_from(award:)
      @award_begin_date = self.award.award_begin_date
      @award_end_date = self.award.award_end_date
      @award_end_date_minus_one_day = self.award.award_end_date - 1.day
      @current_award_indicator = self.award.cur_award_ind
      @number_of_hours = self.award.number_hours
    end

    def clearCaseVariable
      @caseAwardID =  nil
      @caseStartDate =  nil
      @caseEndDate =  nil
      @caseCreditHours =  nil
      @caseMonthlyRate = nil
      @casePaymentDate = nil
      @caseTrace =  nil
    end

    def clearCertVariables
      @openCert = false
      @openCertAwardId = nil
      @openCertCreditHours = nil
      @openCertMonthlyRate = nil
      @openCertPaymentDate = nil
    end

    def addEnrollmentToEnrollments
      user_profile = self.user_profile
      award_id = @caseAwardID
      act_begin = @caseStartDate
      act_end = @caseEndDate
      number_hours = @caseCreditHours
      monthly_rate = @caseMonthlyRate
      payment_date = @casePaymentDate
      trace = @caseTrace

      verification = Verification.build(
        user_profile:, award_id:,
        act_begin:, act_end:,
        number_hours:, monthly_rate:,
        payment_date:, trace:
      )

      @enrollments.push(verification)

      self.clearCaseVariable
    end

    def eval_case_eom
      return unless self.dlc_before_ldpm?
      return unless self.last_day_of_month?
      return unless @award_begin_date < self.today
      return if self.aed_before_today?
      return unless self.dlc_before_abd?

      @caseAwardID = self.award.id
      @caseStartDate = self.award.award_begin_date
      @caseEndDate = self.today
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_eom
      
      self.addEnrollmentToEnrollments
    end

    def flag_open_cert
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return unless @award_end_date.blank?

      @openCert = true
      @openCertAwardId = self.award.id
      @openCertCreditHours = self.award.number_hours
      @openCertMonthlyRate = self.award.monthly_rate
      @openCertPaymentDate = self.award.payment_date
    end

    def eval_case_1a
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return unless @award_end_date.present?
      return if self.areDatesTheSame(@award_end_date, self.date_last_certified) 
      return unless self.current_rec_ended
      return unless self.compareTwoDatesDate1GreaterThanDate2ReturnBoolean(@award_end_date, self.last_day_of_previous_month)
      return unless self.areDatesTheSame(self.award.award_begin_date, self.award.award_end_date)

      @caseAwardID = self.award.id
      @caseStartDate = self.date_last_certified
      @caseEndDate = self.last_day_of_previous_month
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_1a

      @supressFutureAward = true

      self.addEnrollmentToEnrollments
    end

    def eval_case_1b
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return unless @award_end_date.present?
      return if self.areDatesTheSame(@award_end_date, self.date_last_certified) 
      return unless self.current_rec_ended

      @caseAwardID = self.award.id
      @caseStartDate = self.date_last_certified
      @caseEndDate = @award_end_date_minus_one_day
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_1b

      self.addEnrollmentToEnrollments
    end

    def eval_case_2
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return unless @award_end_date.present?
      return if self.areDatesTheSame(@award_end_date, self.date_last_certified)
      return unless self.ldpm_before_aed?
      return if self.ldpm_before_abd?

      @caseAwardID = self.award.id
      @caseStartDate = self.date_last_certified
      @caseEndDate = self.last_day_of_previous_month
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_2

      self.addEnrollmentToEnrollments
    end

    def eval_case_3
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'C'
      return unless @award_end_date.present?
      return if self.areDatesTheSame(@award_end_date, self.date_last_certified) 

      @caseAwardID = self.award.id
      @caseStartDate = self.date_last_certified
      @caseEndDate = @award_end_date_minus_one_day
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_3

      self.addEnrollmentToEnrollments
    end

    def eval_case_4
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supressFutureAward
      return unless @openCert
      return unless self.ldpm_before_abd?

      @caseAwardID = @openCertAwardId
      @caseStartDate = self.date_last_certified
      @caseEndDate = self.last_day_of_previous_month
      @caseCreditHours = @openCertCreditHours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = @openCertPaymentDate
      @caseTrace = :case_4

      self.addEnrollmentToEnrollments
      self.clearCertVariables
    end

    def eval_case_5
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supressFutureAward
      return unless @openCert
      return unless self.ldpm_before_aed?
      return if self.ldpm_before_abd?

      @caseAwardID = @openCertAwardId
      @caseStartDate = self.date_last_certified
      @caseEndDate = @award_end_date_minus_one_day
      @caseCreditHours = @openCertCreditHours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = @openCertPaymentDate
      @caseTrace = :case_5

      self.addEnrollmentToEnrollments
      self.clearCertVariables
    end

    def eval_case_6
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supressFutureAward
      return if self.ldpm_before_abd?
      return unless self.date_last_certified.blank?

      @caseAwardID = self.award.id
      @caseStartDate = self.award.award_begin_date
      @caseEndDate = self.last_day_of_previous_month
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_6

      self.addEnrollmentToEnrollments
    end

    def eval_case_7
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supressFutureAward
      return if self.ldpm_before_abd?
      return unless self.ldpm_before_aed?

      @caseAwardID = self.award.id
      @caseStartDate = self.award.award_begin_date
      @caseEndDate = self.last_day_of_previous_month
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_7

      self.addEnrollmentToEnrollments
    end

    def eval_case_8
      return unless self.dlc_before_ldpm?
      return unless @current_award_indicator == 'F'
      return if @supressFutureAward
      return if self.ldpm_before_abd?

      @caseAwardID = self.award.id
      @caseStartDate = self.award.award_begin_date
      @caseEndDate = @award_end_date_minus_one_day
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_8

      self.addEnrollmentToEnrollments
    end

    def eval_case_9
      return if self.dlc_before_ldpm?
      return unless self.aed_before_today?
      return unless self.areDatesTheSame(self.award.award_begin_date, self.award.award_end_date)

      @caseAwardID = self.award.id
      @caseStartDate = self.date_last_certified
      @caseEndDate = @award_end_date_minus_one_day
      @caseCreditHours = self.award.number_hours
      @caseMonthlyRate = self.award.monthly_rate
      @casePaymentDate = self.award.payment_date
      @caseTrace = :case_9

      self.addEnrollmentToEnrollments
    end

    public

    def enrollments
      return [] if self.queued_verifications?
      return @enrollments unless @enrollments.nil?

      self.setup
      self.awards.each do |award|
        self.award = award
        self.extract_data_from(award:)

        self.eval_case_eom
        self.flag_open_cert || self.eval_case_1a || self.eval_case_1b || self.eval_case_2 || self.eval_case_3
        self.eval_case_4 || self.eval_case_5
        self.eval_case_6 || self.eval_case_7 || self.eval_case_8
        self.eval_case_9
      end

      @enrollments
    end

    alias_method :pending_verifications, :enrollments
  end
end