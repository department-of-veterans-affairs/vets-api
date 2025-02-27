# frozen_string_literal: true

require 'debt_management_center/base_service'

module DebtsApi
  class V0::OneDebtLetterService
    def initialize(user)
      @user = user
    end

    def get_pdf
      debt_letter_pdf = Prawn::Document.new(page_size: 'LETTER') do |pdf|
        add_and_format_logo(pdf)
        pdf.move_down 30
        add_header_columns(pdf)
      end.render

      legalese_pdf = load_legalese_pdf
      combined_pdf = CombinePDF.parse(debt_letter_pdf) << legalese_pdf

      combined_pdf.to_pdf
    end

    def save_pdf(filename = default_filename)
      save_pdf_content(filename, get_pdf)
      filename
    end

    private

    def add_header_columns(pdf)
      header_y = pdf.bounds.height - 75

      # Left column (Veteran Info)
      bounding_box(pdf, 0, header_y, pdf.bounds.width / 2) do
        add_text_box(pdf, formatted_user[:first_name_last_name])
        add_text_box(pdf, formatted_user[:address][:address_line_one])
        add_text_box(pdf, formatted_user[:address][:address_line_two])
        add_text_box(pdf, formatted_user[:address][:city_state_zip])
      end

      # Right column (Date, File Number, Questions)
      bounding_box(pdf, (pdf.bounds.width / 2) + 100, header_y, (pdf.bounds.width / 2) - 100) do
        add_text_box(pdf, Time.current.strftime('%m/%d/%Y'))
        add_text_box(pdf, "File Number: #{formatted_user[:file_number]}")
        add_text_box(pdf, 'Questions? https://ask.va.gov')
      end
    end

    def bounding_box(pdf, x, y, width, &)
      pdf.bounding_box([x, y], width:, &)
    end

    def add_text_box(pdf, text)
      pdf.text_box(
        text,
        at: [10, pdf.cursor],
        width: pdf.bounds.width - 20,
        height: 20,
        border: 1,
        align: :left,
        size: 10
      )
      pdf.move_down 15
    end

    def add_and_format_logo(pdf)
      logo_path = Rails.root.join('modules', 'debts_api', 'app', 'assets', 'images', 'va_logo.png')
      pdf.image logo_path, at: [(pdf.bounds.width / 2) - (250 / 2), pdf.cursor], width: 250
    end

    def formatted_user
      {
        first_name_last_name: "#{@user.first_name} #{@user.last_name}",
        file_number: user_file_number,
        address: {
          address_line_one: @user.address[:street],
          address_line_two: @user.address[:street2],
          city_state_zip: "#{@user.address[:city]} #{@user.address[:state]} #{@user.address[:postal_code]}"
        }
      }
    end

    def user_file_number
      service = DebtManagementCenter::BaseService.new(@user)
      service.instance_variable_get(:@file_number)
    end

    def default_filename
      Rails.root.join('tmp', 'pdfs', "debt_letter_#{Time.current.strftime('%Y%m%d%H%M%S')}.pdf")
    end

    def save_pdf_content(path, content)
      File.open(path, 'wb') { |file| file.write(content) }
    end

    def load_legalese_pdf
      legalese_path = Rails.root.join(
        'modules', 'debts_api', 'app', 'assets', 'documents', 'one_debt_letter_legal_content.pdf'
      )

      CombinePDF.load(legalese_path)
    end

    def cleanup_temp_file(path)
      File.delete(path) if File.exist?(path)
    end
  end
end
