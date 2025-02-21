# frozen_string_literal: true

module ClaimsApi
  class EvidenceWaiver
    # Example call to use this tool:
    #
    # waiver = ClaimsApi::EvidenceWaiver.new(target_veteran: target_veteran)
    # pdf = waiver.construct(response: params[:response])
    def initialize(auth_headers:)
      @page1_path = nil
      @first_name = auth_headers['va_eauth_firstName']
      @last_name = auth_headers['va_eauth_lastName']
      @middle_name = auth_headers['va_eauth_middleName']
    end

    def construct(response: true)
      fill_pdf(response)
    end

    protected

    # @return [String] Path to page 1 pdf template file
    def page1_template_path
      Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', '5103', '1.pdf')
    end

    def signature
      name = [@first_name, @middle_name, @last_name].compact.join(' ')
      "#{name[0...27]} - signed via api.va.gov"
    end

    def page1_options(response)
      {
        'checkbox.yes': response == false ? 0 : 1,
        'checkbox.no': response == false ? 1 : 0,
        date: I18n.l(Time.zone.now.to_date, format: :va_form),
        signature:
      }
    end

    private

    #
    # Fill in pdf form fields based on data provided.
    #
    # @param data [Hash] Data to fill in pdf form with
    def fill_pdf(response)
      pdftk = PdfForms.new(Settings.binaries.pdftk)

      temp_path = Rails.root.join('tmp', "5103_#{Time.now.to_i}_page_1.pdf")
      pdftk.fill_form(
        page1_template_path,
        temp_path,
        page1_options(response),
        flatten: true
      )

      @page1_path = temp_path
    end
  end
end
