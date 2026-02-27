# frozen_string_literal: true

require 'survivors_benefits/benefits_intake/submit_claim_job'
require 'pdf_fill/filler'

module SurvivorsBenefits
  class SavedClaim < ::SavedClaim
    # SurvivorsBenefits 21P-534EZ Active::Record
    # @see app/model/saved_claim
    #
    include HasStructuredData

    # Survivors Benefits Form ID
    FORM = SurvivorsBenefits::FORM_ID

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      ['Department of Veteran\'s Affairs',
       'Pension Intake Center',
       'P.O. Box 5365',
       'Janesville, Wisconsin 53547-5365']
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'NCA'
    end

    # the VBMS document type for _this_ claim type
    def document_type
      1292
    end

    # Utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      parsed_form['email'] || 'test@example.com' # TODO: update this when we have a real email field
    end

    # Utility function to retrieve veteran first name from form
    #
    # @return [String]
    def veteran_first_name
      parsed_form.dig('veteranFullName', 'first')
    end

    # Utility function to retrieve veteran last name from form
    #
    # @return [String]
    def veteran_last_name
      parsed_form.dig('veteranFullName', 'last')
    end

    # Utility function to retrieve claimant first name from form
    #
    # @return [String]
    def claimant_first_name
      parsed_form.dig('claimantFullName', 'first')
    end

    ##
    # claim attachment list
    #
    # @see PersistentAttachment
    #
    # @return [Array<String>] list of attachments
    #
    def attachment_keys
      [:files].freeze
    end

    # Run after a claim is saved, this processes any files and workflows that are present
    # and sends them to our internal partners for processing.
    # Only removed Sidekiq call from super
    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }
    end

    ##
    # Generates a PDF from the saved claim data
    #
    # @param file_name [String, nil] Optional name for the output PDF file
    # @param fill_options [Hash] Additional options for PDF generation
    # @return [String] Path to the generated PDF file
    #
    def to_pdf(file_name = nil, fill_options = {})
      pdf_path = ::PdfFill::Filler.fill_form(self, file_name, fill_options)
      return unless pdf_path

      form_data = form.present? ? parsed_form : {}

      SurvivorsBenefits::PdfFill::Va21p534ez.stamp_signature(pdf_path, form_data)
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(email_type)
      SurvivorsBenefits::NotificationEmail.new(id).deliver(email_type)
    end

    # BEGIN IBM

    ##
    # Converts the form_data into json that can be read by the IBM - GOVCIO mms connection
    #
    def to_ibm
      structured_data_service = SurvivorsBenefits::StructuredData::StructuredDataService.new(parsed_form)
      structured_data_service.build_structured_data
    end

    ##
    # Section VII
    # Build the D.I.C. structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_dic_info(form)
      fields = build_dic_type_fields(form['benefit'])
      treatments = form['treatments'] || []
      treatments&.each_with_index do |treatment, index|
        center_num = index + 1
        fields.merge!(
          {
            "NAME_LOC_MED_CENTER_#{center_num}" => treatment['facility'],
            "DATE_OF_TREATMENT_START#{center_num}" => format_date(treatment['startDate']),
            "DATE_OF_TREATMENT_END#{center_num}" => format_date(treatment['endDate'])
          }
        )
      end
      fields
    end

    ##
    # Section IX
    # Build Income and Asset structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_income_and_assets_info(form)
      build_income_fields(form['incomeEntries'])
        .merge!(y_n_pair(form['landMarketable'], 'MARKETABLE_LAND_2ACR_Y', 'MARKETABLE_LAND_2ACR_N'))
        .merge!(y_n_pair(form['transferredAssets'], 'TRANSFER_ASSETS_LAST3Y_Y', 'TRANSFER_ASSETS_LAST3Y_N'))
        .merge!(y_n_pair(form['homeOwnership'], 'OWN_PRIMARY_RESIDENCE_Y', 'OWN_PRIMARY_RESIDENCE_N'))
        .merge!(y_n_pair(form['homeAcreageMoreThanTwo'], 'RESLOT_OVER_2ACR_Y', 'RESLOT_OVER_2ACR_N'))
        .merge!(y_n_pair(form['moreThanFourIncomeSources'], 'MORETHAN4_INCSOURCE_Y', 'MORETHAN4_INCSOURCE_N'))
        .merge!(y_n_pair(form['otherIncome'], 'PREV_YEAR_OTHER_INCOME_YES', 'PREV_YEAR_OTHER_INCOME_NO'))
        .merge!(y_n_pair(form['totalNetWorth'], 'ASSETS_OVER_25K_Y', 'ASSETS_OVER_25K_N'))
        .merge!(
          {
            'AMNT_ESTIMATE_ASSETS' => form['netWorthEstimation'] || 0,
            'AMNT_VALUE_OF_LOT' => form['homeAcreageValue'] || 0
          }
        )
    end

    ##
    # Section X
    # Build the medical, last, and/or burial expenses structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_medical_last_burial_expenses(form)
      fields = y_n_pair(reportable_reimbursment?(form), 'UNREIMBURSED_MED_EXPENSES_Y', 'UNREIMBURSED_MED_EXPENSES_N')
      fields.merge!(build_care_expense_fields(form['careExpenses'] || []))
            .merge!(build_medical_expense_fields(form['medicalExpenses'] || []))
    end

    ##
    # Section XI
    # Build claimant direct deposit structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_claimant_direct_deposit_fields(account)
      return {} unless account

      {
        'NAME_FINANCIAL_INSTITUTE' => account['bankName'],
        'ROUTING_TRANSIT_NUMBER' => account['routingNumber'],
        'CHECKING_ACCOUNT_CB' => account['accountType'] == 'CHECKING',
        'SAVINGS_ACCOUNT_CB' => account['accountType'] == 'SAVINGS',
        'NO_ACCOUNT_CB' => account['accountType'] == 'NO_ACCOUNT',
        'AccountNumber' => account['accountNumber']
      }
    end

    ##
    # Section XII
    # Build claim certification structured data entries.
    #
    # @param form [Hash]
    # @return [Hash]
    def build_claim_certification_fields(form)
      {
        'CB_FURTHER_EVD_CLAIM_SUPPORT' => false,
        'CLAIM_TYPE_FULLY_DEVELOPED_CHK' => true,
        'CLAIMANT_SIGNATURE_X' => form['claimantSignatureX'],
        'CLAIMANT_SIGNATURE' => form['claimantSignature'],
        'DATE_OF_CLAIMANT_SIGNATURE' => format_date(form['claimantSignatureDate'])
      }
    end

    def build_income_fields(incomes, fields = {})
      incomes&.each_with_index do |income, index|
        income_num = index + 1
        fields.merge!(expand_monthly_income_fields(income_num, income['monthlyIncome']))
        fields.merge!(build_currency_fields(income['monthlyIncome'], monthly_income_keys(income_num)))
        fields.merge!(
          {
            "CB_INC_RECIPIENT#{income_num}_SP" => income['recipient'] == 'SURVIVING_SPOUSE',
            "CB_INC_RECIPIENT#{income_num}_CHILD" => income['recipient'] == 'CHILD',
            "NAME_OF_CHILD_INCOMETYPE#{income_num}" => income['recipientName'] || '',
            "CB_INCOMETYPE#{income_num}_SS" => income['incomeType'] == 'SOCIAL_SECURITY',
            "CB_INCOMETYPE#{income_num}_PENSION" => income['incomeType'] == 'PENSION_RETIREMENT',
            "CB_INCOMETYPE#{income_num}_CIVIL" => income['incomeType'] == 'CIVIL_SERVICE',
            "CB_INCOMETYPE#{income_num}_INTEREST" => income['incomeType'] == 'INTEREST_DIVIDENDS',
            "CB_INCOMETYPE#{income_num}_OTHER" => income['incomeType'] == 'OTHER',
            "CB_INCOMETYPE#{income_num}_OTHERSPECIFY" => income['incomeTypeOther'] || '',
            "INCOME_PAYER_#{income_num}" => income['incomePayer'] || ''
          }
        )
      end
      fields
    end

    def monthly_income_keys(income_num)
      {
        full: "MONTHLY_GROSS_#{income_num}",
        thousands: "MONTHLY_GROSS_#{income_num}_THSNDS",
        hundreds: "MONTHLY_GROSS_#{income_num}_HNDRDS",
        cents: "MONTHLY_GROSS_#{income_num}_CENTS" 
      }
    end

    def expand_monthly_income_fields(income_num, monthly_income)
      {
        "MONTHLY_GROSS_#{income_num}" => monthly_income || 0,
        "MONTHLY_GROSS_#{income_num}_THSNDS" => monthly_income / 1000,
        "MONTHLY_GROSS_#{income_num}_HNDRDS" => monthly_income % 1000,
        "MONTHLY_GROSS_#{income_num}_CENTS" => 0
      }
    end

    def reportable_reimbursment?(form)
      form['careExpenses'].blank? && form['medicalExpenses'].blank?
    end

    def build_care_expense_fields(care_expenses, fields = {})
      care_expenses&.each_with_index do |expense, index|
        expense_num = index + 1
        fields.merge!(build_currency_fields(expense['paymentAmount'], care_expense_keys(expense_num)))
        fields.merge!(
          {
            "CB_EXPENSES_PAID_SP#{expense_num}" => expense['recipient'] == 'SURVIVING_SPOUSE',
            "CB_EXPENSES_PAID_OTHER#{expense_num}" => expense['recipient'] == 'OTHER',
            "NAME_OF_DEPENDENT#{expense_num}" => expense['recipientName'],
            "NAME_OF_PROVIDER#{expense_num}" => expense['provider'],
            "CB_PROVIDER_TYPE_CAREFACILITY#{expense_num}" => expense['careType'] == 'CARE_FACILITY',
            "CB_PROVIDER_TYPE_INHOMECARE#{expense_num}" => expense['careType'] == 'IN_HOME_CARE_ATTENDANT',
            "PMNT_RATE_INHOMECARE#{expense_num}" => expense['ratePerHour'],
            "HRS_PER_WEEK#{expense_num}" => expense['hoursPerWeek'],
            "PROVIDER_START_DATE#{expense_num}" => format_date(expense.dig('careDateRange', 'from')),
            "PROVIDER_END_DATE#{expense_num}" => format_date(expense.dig('careDateRange', 'to')),
            "CB_NO_END_DATE#{expense_num}" => expense['noCareEndDate'] || false,
            "CB_PAYMENT_MONTHLY#{expense_num}" => expense['paymentFrequency'] == 'MONTHLY',
            "CB_PAYMENT_ANNUALLY#{expense_num}" => expense['paymentFrequency'] == 'ANNUALLY'
          }
        )
      end
      fields
    end

    def build_medical_expense_fields(medical_expenses, fields = {})
      medical_expenses&.each_with_index do |expense, index|
        expense_num = index + 1
        fields.merge!(build_currency_fields(expense['paymentAmount'], medical_expense_keys(expense_num)))
        fields.merge!(
          {
            "MED_EXPENSES_SP#{expense_num}" => expense['recipient'] == 'SURVIVING_SPOUSE',
            "MED_EXPENSES_VET#{expense_num}" => expense['recipient'] == 'VETERAN',
            "MED_EXPENSES_CHILD#{expense_num}" => expense['recipient'] == 'CHILD',
            "MED_EXPENSES_CHILDNAME#{expense_num}" => expense['childName'],
            "PAID_TO_PROVIDER#{expense_num}" => expense['provider'],
            "PAID_TO_PURPOSE#{expense_num}" => expense['purpose'],
            "DATE_COSTS_INCURRED_START#{expense_num}" => format_date(expense.dig('medicalDateRange', 'from')),
            "CB_PMNT_FREQUENCY_MONTHLY#{expense_num}" => expense['paymentFrequency'] == 'MONTHLY',
            "CB_PMNT_FREQUENCY_ANNUALLY#{expense_num}" => expense['paymentFrequency'] == 'ANNUALLY',
            "CB_PMNT_FREQUENCY_ONETIME#{expense_num}" => expense['paymentFrequency'] == 'ONE_TIME'
          }
        )
      end
      fields
    end

    def care_expense_keys(expense_num)
      {
        full: "AMNT_YOU_PAY#{expense_num}",
        thousands: "AMNT_YOU_PAY_#{expense_num}_THSNDS",
        hundreds: "AMNT_YOU_PAY_#{expense_num}_HNDRDS",
        cents: "AMNT_YOU_PAY_#{expense_num}_CENTS"
      }
    end

    def medical_expense_keys(expense_num)
      {
        full: "MEDAMNT_YOU_PAY#{expense_num}",
        thousands: "MEDAMNT_YOU_PAY#{expense_num}_THSNDS",
        hundreds: "MEDAMNT_YOU_PAY#{expense_num}_HNDRDS",
        cents: "MEDAMNT_YOU_PAY#{expense_num}_CENTS"
      }
    end
  end
end
