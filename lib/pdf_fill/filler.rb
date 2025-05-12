# frozen_string_literal: true

require 'pdf_fill/extras_generator'
require 'pdf_fill/extras_generator_v2'
require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va210781v2'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_fill/forms/va1010ez'
require 'pdf_fill/forms/va686c674'
require 'pdf_fill/forms/va686c674v2'
require 'pdf_fill/forms/va281900'
require 'pdf_fill/forms/va288832'
require 'pdf_fill/forms/va21674'
require 'pdf_fill/forms/va21674v2'
require 'pdf_fill/forms/va210538'
require 'pdf_fill/forms/va261880'
require 'pdf_fill/forms/va5655'
require 'pdf_fill/forms/va2210216'
require 'pdf_fill/forms/va2210215'
require 'utilities/date_parser'

# rubocop:disable Metrics/ModuleLength
module PdfFill
  # Provides functionality to fill and process PDF forms.
  #
  # This module includes methods to register form classes, fill out PDF forms, and handle extra PDF generation.
  module Filler
    class PdfFillerException < StandardError; end
    module_function

    # A PdfForms instance for handling standard PDF forms.
    PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)

    # A PdfForms instance for handling Unicode PDF forms with XFdf data format.
    UNICODE_PDF_FORMS = PdfForms.new(Settings.binaries.pdftk, data_format: 'XFdf', utf8_fields: true)

    # A hash mapping form IDs to their corresponding form classes.
    # This constant is intentionally mutable.
    FORM_CLASSES = {} # rubocop:disable Style/MutableConstant

    ##
    # Registers a form class with a specific form ID.
    #
    # @param form_id [String] The form ID to register.
    # @param form_class [Class] The class associated with the form ID.
    #
    def register_form(form_id, form_class)
      FORM_CLASSES[form_id] = form_class
    end

    # Registers form classes for various form IDs.
    {
      '21-4142' => PdfFill::Forms::Va214142,
      '21-0781a' => PdfFill::Forms::Va210781a,
      '21-0781' => PdfFill::Forms::Va210781,
      '21-0781V2' => PdfFill::Forms::Va210781v2,
      '21-8940' => PdfFill::Forms::Va218940,
      '10-10CG' => PdfFill::Forms::Va1010cg,
      '10-10EZ' => PdfFill::Forms::Va1010ez,
      '686C-674' => PdfFill::Forms::Va686c674,
      '686C-674-V2' => PdfFill::Forms::Va686c674v2,
      '28-1900' => PdfFill::Forms::Va281900,
      '28-8832' => PdfFill::Forms::Va288832,
      '21-674' => PdfFill::Forms::Va21674,
      '21-674-V2' => PdfFill::Forms::Va21674v2,
      '21-0538' => PdfFill::Forms::Va210538,
      '26-1880' => PdfFill::Forms::Va261880,
      '5655' => PdfFill::Forms::Va5655,
      '22-10216' => PdfFill::Forms::Va2210216,
      '22-10215' => PdfFill::Forms::Va2210215
    }.each do |form_id, form_class|
      register_form(form_id, form_class)
    end

    ##
    # Combines extra pages into the main PDF if necessary.
    #
    # @param old_file_path [String] The path to the original PDF file.
    # @param extras_generator [ExtrasGenerator] The generator for extra pages.
    #
    # @return [String] The path to the final combined PDF.
    #
    def combine_extras(old_file_path, extras_generator)
      if extras_generator.text?
        file_path = "#{old_file_path.gsub('.pdf', '')}_final.pdf"
        extras_path = extras_generator.generate

        PDF_FORMS.cat(old_file_path, extras_path, file_path)

        File.delete(extras_path)
        File.delete(old_file_path)

        file_path
      else
        old_file_path
      end
    end

    ##
    # Fills a form based on the provided saved claim and options.
    #
    # @param saved_claim [SavedClaim] The saved claim containing form data.
    # @param file_name_extension [String, nil] Optional file name extension.
    # @param fill_options [Hash] Options for filling the form.
    #
    # @raise [PdfFillerException] If the form is not found.
    # @return [String] The path to the filled PDF form.
    #
    def fill_form(saved_claim, file_name_extension = nil, fill_options = {})
      form_id = saved_claim.form_id
      form_class = FORM_CLASSES[form_id]

      raise PdfFillerException, "Form #{form_id} was not found." unless form_class

      process_form(form_id, saved_claim.parsed_form, form_class, file_name_extension || saved_claim.id, fill_options)
    end

    ##
    # Fills an ancillary form based on the provided data and form ID.
    #
    # @param form_data [Hash] The data to fill in the form.
    # @param claim_id [String] The ID of the claim.
    # @param form_id [String] The form ID.
    #
    # @return [String] The path to the filled PDF form.
    #
    def fill_ancillary_form(form_data, claim_id, form_id, fill_options = {})
      process_form(form_id, form_data, FORM_CLASSES[form_id], claim_id, fill_options)
    end

    ##
    # Processes a form by filling it with data and saving it to a file.
    #
    # @param form_id [String] The form ID.
    # @param form_data [Hash] The data to fill in the form.
    # @param form_class [Class] The class associated with the form ID.
    # @param file_name_extension [String] The file name extension for the output PDF.
    # @param fill_options [Hash] Options for filling the form.
    #
    # @return [String] The path to the filled PDF form.
    #
    # rubocop:disable Metrics/MethodLength
    def process_form(form_id, form_data, form_class, file_name_extension, fill_options = {})
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{form_id}_#{file_name_extension}.pdf"
      merged_form_data = form_class.new(form_data).merge_fields(fill_options)
      submit_date = Utilities::DateParser.parse(
        merged_form_data['signatureDate'] || fill_options[:created_at] || Time.now.utc
      )

      hash_converter = make_hash_converter(form_id, form_class, submit_date, fill_options)
      new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

      has_template = form_class.const_defined?(:TEMPLATE)
      template_path = has_template ? form_class::TEMPLATE : "lib/pdf_fill/forms/pdfs/#{form_id}.pdf"
      unicode_pdf_form_list = [SavedClaim::CaregiversAssistanceClaim::FORM,
                               EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2]
      (form_id.in?(unicode_pdf_form_list) ? UNICODE_PDF_FORMS : PDF_FORMS).fill_form(
        template_path, file_path, new_hash, flatten: Rails.env.production?
      )
      binding.pry

      # If the form is being generated with the overflow redesign, stamp the top and bottom of the document before the
      # form is combined with the extras overflow pages. This allows the stamps to be placed correctly for the redesign
      # implemented in lib/pdf_fill/extras_generator_v2.rb.
      if fill_options.fetch(:extras_redesign, false) && submit_date.present?
        file_path = stamp_form(file_path, submit_date)
      end
      output = combine_extras(file_path, hash_converter.extras_generator)
      Rails.logger.info('PdfFill done', fill_options.merge(form_id:, file_name_extension:, extras: output != file_path))
      output
    end
    # rubocop:enable Metrics/MethodLength

    def make_hash_converter(form_id, form_class, submit_date, fill_options)
      extras_generator =
        if fill_options.fetch(:extras_redesign, false)
          ExtrasGeneratorV2.new(
            form_name: form_id.sub(/V2\z/, ''),
            submit_date:,
            question_key: form_class::QUESTION_KEY,
            start_page: form_class::START_PAGE,
            sections: form_class::SECTIONS,
            label_width: form_class::DEFAULT_LABEL_WIDTH
          )
        else
          ExtrasGenerator.new
        end
      HashConverter.new(form_class.date_strftime, extras_generator)
    end

    def stamp_form(file_path, submit_date)
      original_path = file_path
      sig = "Signed electronically and submitted via VA.gov at #{format_timestamp(submit_date)}. " \
            'Signee signed with an identity-verified account.'
      initial_stamp_path = PDFUtilities::DatestampPdf.new(file_path).run(
        text: sig, x: 5, y: 5, text_only: true, size: 9
      )
      file_path = initial_stamp_path
      file_path = PDFUtilities::DatestampPdf.new(initial_stamp_path).run(
        text: 'VA.gov Submission', x: 510, y: 775, text_only: true, size: 9
      )
      file_path
    rescue => e
      Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
      original_path
    ensure
      File.delete(initial_stamp_path) if initial_stamp_path
    end

    # Formats the timestamp for the PDF footer
    def format_timestamp(datetime)
      return nil if datetime.blank?

      "#{datetime.utc.strftime('%H:%M')} UTC #{datetime.utc.strftime('%Y-%m-%d')}"
    end
  end
end
# rubocop:enable Metrics/ModuleLength



# {"F[0].#subform[1].InformationIsLimitedToWhatIsWrittenInThisSpace[0]"=>"true","F[0].provider.Provider_Or_Facility_Name[0]"=>"provider 1","F[0].provider.numberAndStreet[0]"=>"123 Main Street","F[0].provider.apartmentOrUnitNumber[0]"=>"1B","F[0].provider.city[0]"=>"Baltimore","F[0].provider.state[0]"=>"MD","F[0].provider.country[0]"=>"US","F[0].provider.postalCode_FirstFiveNumbers[0]"=>"21200","F[0].provider.postalCode_LastFourNumbers[0]"=>"1111","F[0].provider.dateRangeStart0[0]"=>"01/01/1980","F[0].provider.dateRangeEnd0[0]"=>"01/01/1985","F[0].provider.dateRangeStart1[0]"=>"01/01/1986","F[0].provider.dateRangeEnd1[0]"=>"01/01/1987","F[0].provider.Provider_Or_Facility_Name[1]"=>"provider 2","F[0].provider.numberAndStreet[1]"=>"456 Main Street","F[0].provider.apartmentOrUnitNumber[1]"=>"1B","F[0].provider.city[1]"=>"Baltimore","F[0].provider.state[1]"=>"MD","F[0].provider.country[1]"=>"US","F[0].provider.postalCode_FirstFiveNumbers[1]"=>"21200","F[0].provider.postalCode_LastFourNumbers[1]"=>"1111","F[0].provider.dateRangeStart0[1]"=>"02/01/1980","F[0].provider.dateRangeEnd0[1]"=>"02/01/1985","F[0].provider.dateRangeStart1[1]"=>"02/01/1986","F[0].provider.dateRangeEnd1[1]"=>"02/01/1987","F[0].provider.Provider_Or_Facility_Name[2]"=>"provider 3","F[0].provider.numberAndStreet[2]"=>"789 Main Street","F[0].provider.apartmentOrUnitNumber[2]"=>"1B","F[0].provider.city[2]"=>"Baltimore","F[0].provider.state[2]"=>"MD","F[0].provider.country[2]"=>"US","F[0].provider.postalCode_FirstFiveNumbers[2]"=>"21200","F[0].provider.postalCode_LastFourNumbers[2]"=>"1111","F[0].provider.dateRangeStart0[2]"=>"03/01/1980","F[0].provider.dateRangeEnd0[2]"=>"03/01/1985","F[0].provider.dateRangeStart1[2]"=>"03/01/1986","F[0].provider.dateRangeEnd1[2]"=>"03/01/1987","F[0].provider.Provider_Or_Facility_Name[3]"=>"provider 4","F[0].provider.numberAndStreet[3]"=>"101 Main Street","F[0].provider.apartmentOrUnitNumber[3]"=>"1B","F[0].provider.city[3]"=>"Baltimore","F[0].provider.state[3]"=>"MD","F[0].provider.country[3]"=>"US","F[0].provider.postalCode_FirstFiveNumbers[3]"=>"21200","F[0].provider.postalCode_LastFourNumbers[3]"=>"1111","F[0].provider.dateRangeStart0[3]"=>"04/01/1980","F[0].provider.dateRangeEnd0[3]"=>"04/01/1985","F[0].provider.dateRangeStart1[3]"=>"04/01/1986","F[0].provider.dateRangeEnd1[3]"=>"04/01/1987","F[0].provider.Provider_Or_Facility_Name[4]"=>"provider 5","F[0].provider.numberAndStreet[4]"=>"102 Main Street","F[0].provider.apartmentOrUnitNumber[4]"=>"1B","F[0].provider.city[4]"=>"Baltimore","F[0].provider.state[4]"=>"MD","F[0].provider.country[4]"=>"US","F[0].provider.postalCode_FirstFiveNumbers[4]"=>"21200","F[0].provider.postalCode_LastFourNumbers[4]"=>"1111","F[0].provider.dateRangeStart0[4]"=>"05/01/1980","F[0].provider.dateRangeEnd0[4]"=>"05/01/1985","F[0].provider.dateRangeStart1[4]"=>"05/01/1986","F[0].provider.dateRangeEnd1[4]"=>"05/01/1987","F[0].Page_1[0].VAFileNumber[0]"=>"796068949","F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]"=>"796","F[0].Page_1[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]"=>"06","F[0].Page_1[0].VeteransSocialSecurityNumber_LastFourNumbers[0]"=>"8949","F[0].Page_1[0].VeteranFirstName[0]"=>"Beyonce","F[0].Page_1[0].VeteranLastName[0]"=>"Knowles","F[0].Page_1[0].DOBmonth[0]"=>"02","F[0].Page_1[0].DOBday[0]"=>"12","F[0].Page_1[0].DOByear[0]"=>"1809","F[0].Page_1[0].MailingAddress_City[0]"=>"Portland","F[0].Page_1[0].MailingAddress_Country[0]"=>"US","F[0].Page_1[0].MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]"=>"12345","F[0].Page_1[0].MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]"=>"6789","F[0].Page_1[0].MailingAddress_NumberAndStreet[0]"=>"1234 Couch Street","F[0].Page_1[0].MailingAddress_ApartmentOrUnitNumber[0]"=>"See add'l info page","F[0].Page_1[0].MailingAddress_StateOrProvince[0]"=>"OR","F[0].Page_1[0].E_Mail_Address[0]"=>"test@email.com","F[0].Page_1[0].E_Mail_Address[1]"=>"2024561111","F[0].Page_1[0].VeteransServiceNumber_If_Applicable[0]"=>"","F[0].#subform[1].DateSigned_Month_Day_Year[0]"=>"11/09/2024","F[0].#subform[14].VAFileNumber[0]"=>"796068949","F[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]"=>"796","F[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]"=>"06","F[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]"=>"8949","F[0].#subform[14].SSN1[0]"=>"796","F[0].#subform[14].SSN2[0]"=>"06","F[0].#subform[14].SSN3[0]"=>"8949","F[0].#subform[14].FirstThreeNumbers[0]"=>"796","F[0].#subform[14].SecondTwoNumbers[0]"=>"06","F[0].#subform[14].LastFourNumbers[0]"=>"8949","F[0].#subform[14].VeteranFirstName[0]"=>"Beyonce","F[0].#subform[14].VeteranLastName[0]"=>"Knowles","F[0].#subform[1].SignatureField11[0]"=>"/es/ Beyonce Knowles","F[0].#subform[1].PrintedNameOfPersonAuthorizingDisclosure[0]"=>"Beyonce Knowles","F[0].#subform[14].Month[0]"=>"02","F[0].#subform[14].Day[0]"=>"12","F[0].#subform[14].Year[0]"=>"1809"}