# frozen_string_literal: true

require 'debt_management_center/base_service'

module DebtsApi
  class V0::OneDebtLetterService
    def initialize(user)
      @user = user
    end

    def get_pdf
      Prawn::Document.new(page_size: 'LETTER') do |pdf|
        add_and_format_logo(pdf)
        pdf.move_down 30
        add_header_columns(pdf)
      end.render
    end

    def save_pdf(filename = default_filename)
      temp_path = Rails.root.join("tmp", "debt_letter_temp.pdf")

      begin
        save_pdf_content(temp_path, get_pdf)

        legalese_pdf = load_and_validate_legalese_pdf
        billing_pdf = CombinePDF.load(temp_path)

        combined_pdf = billing_pdf << legalese_pdf # Append legalese pages

        save_pdf_content(filename, combined_pdf.to_pdf)

        cleanup_temp_file(temp_path)

        filename # Return the final path
      rescue StandardError => e
        cleanup_temp_file(temp_path)
        raise "Error combining PDFs: #{e.message}"
      end
    end

    private

    def add_header_columns(pdf)
      header_y = pdf.bounds.height - 75 # this evens out the left and right columns
      # Left column (Veteran Info)
      pdf.bounding_box([0, header_y], width: pdf.bounds.width / 2) do
        pdf.text_box(
          formatted_user[:first_name_last_name], at: [10, pdf.cursor],
          width: pdf.bounds.width - 20, height: 20, border: 1, align: :left, size: 10
        )
        pdf.move_down 15 # Increased spacing
        pdf.text_box(
          formatted_user[:address][:address_line_1], at: [10, pdf.cursor],
          width: pdf.bounds.width - 20, height: 20, border: 1, align: :left, size: 10
        )
        pdf.move_down 15 # Increased spacing
        pdf.text_box(
          "#{formatted_user[:address][:city_state_zip]}", at: [10, pdf.cursor],
          width: pdf.bounds.width - 20, height: 20, border: 1, align: :left, size: 10
        )
      end

      # Right column (Date, File Number, Questions)
      pdf.bounding_box([pdf.bounds.width / 2 + 100, header_y], width: pdf.bounds.width / 2 - 100) do
        pdf.text_box(
          Time.now.strftime('%m/%d/%Y'), at: [10, pdf.cursor],
          width: pdf.bounds.width - 20, height: 20, border: 1, align: :left, size: 10
        )
        pdf.move_down 15
        pdf.text_box(
          "File Number: #{formatted_user[:file_number]}", at: [10, pdf.cursor],
          width: pdf.bounds.width - 20, height: 20, border: 1, align: :left, size: 10
        )
        pdf.move_down 15
        pdf.text_box(
          "Questions? https://ask.va.gov", at: [10, pdf.cursor],
          width: pdf.bounds.width - 20, height: 20, border: 1, align: :left, size: 10
        )
      end
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
          address_line_1: @user.address[:street],
          address_line_2: @user.address[:street2],
          city_state_zip: "#{@user.address[:city]} #{@user.address[:state]} #{@user.address[:postal_code]}"
        }
      }
    end

    def user_file_number
      service = DebtManagementCenter::BaseService.new(@user)
      service.instance_variable_get(:@file_number)
    end

    def default_filename
      Rails.root.join("tmp", "debt_letter_#{Time.current.strftime('%Y%m%d%H%M%S')}.pdf")
    end

    def save_pdf_content(path, content)
      File.open(path, "wb") { |file| file.write(content) }
    end

    def load_and_validate_legalese_pdf
      legalese_path = Rails.root.join("modules", "debts_api", "app", "assets", "documents", "one_debt_letter_legal_content.pdf")

      raise "Legalese PDF not found at #{legalese_path}" unless File.exist?(legalese_path)

      pdf = CombinePDF.load(legalese_path)
      raise "Legalese PDF must have exactly 2 pages, but has #{pdf.pages.length} pages" unless pdf.pages.length == 2

      pdf
    end

    def cleanup_temp_file(path)
      File.delete(path) if File.exist?(path)
    end
  end
end
