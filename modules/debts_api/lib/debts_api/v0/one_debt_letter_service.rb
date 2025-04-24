# frozen_string_literal: true

require 'debt_management_center/debts_service'

module DebtsApi
  module V0
    class OneDebtLetterService
      # rubocop:disable Layout/LineLength
      COPAY_TABLE_DESCRIPTION = '<i>– You are receiving this billing statement because you are currently enrolled in a priority group requiring copayments for treatment of nonservice-connected conditions.</i>'
      COPAY_PAYMENT_INSTRUCTIONS = 'To Pay Your Copay Bills:<br><b>In Person:</b>: At your local Veteran Affairs Medical Center Agent Cashier’s Office<br><b>By Phone</b>: Contact VA at 1-888-827-4817<br><b>Online</b>: Pay by ACH withdrawal from your bank account, or by debit or credit card at www.pay.gov'
      DEBT_PAYMENT_INSTRUCTIONS = "To Pay Your VA Benefit Debt:\n<b>By Phone</b>: Contact VA’s Debt Management Center at 1-800-827-0648\n<b>Online</b>: Pay by ACH withdrawal from your bank account, or by debit or credit card at www.pay.va.gov"
      BENEFITS_TABLE_DESCRIPTION = '<i>– Veterans Benefits Administration overpayments are due to changes in your entitlement which result in you being paid more than you were entitled to receive.</i>'
      # rubocop:enable Layout/LineLength
      COPAY_TOTAL_TEXT = 'Total Copayment Due'
      COPAY_TABLE_TITLE = '<b><i>VA Medical Center Copay Charges</i></b>'
      DEBT_TOTAL_TEXT = 'Total VBA Overpayment Due'

      def initialize(user)
        @user = user
      end

      # rubocop:disable Metrics/MethodLength
      def get_pdf(document = nil)
        return combine_pdfs(document) if document

        debt_letter_pdf = Prawn::Document.new(page_size: 'LETTER') do |pdf|
          add_and_format_logo(pdf)
          pdf.move_down 30
          add_header_columns(pdf)
          pdf.move_down 20
          copays = copays_service[:data]

          if copays.any?
            table_data = [[{ content: COPAY_TABLE_TITLE, inline_format: true }, 'AMOUNT DUE', 'COPAY BILLING REF#']]
            table_data << [{ content: COPAY_TABLE_DESCRIPTION, inline_format: true }, '', '']
            copays.each_with_index do |copay, copay_index|
              copay_details = copay['details']
              copay_details.each_with_index do |detail, index|
                description = add_copay_description(detail, index, copay_index)
                table_data << copay_table_item(description, detail)
              end
              table_data << [copay['station']['facilitYDesc'], '', '']
            end
            formatted_copay_total = copays_amount_due(copays)
            table_data << [{ content: COPAY_TOTAL_TEXT, inline_format: true, align: :right }, formatted_copay_total, '']

            table_data << [{ content: COPAY_PAYMENT_INSTRUCTIONS, inline_format: true }, '', '']
            pdf.table(table_data, width: pdf.bounds.width, cell_style: { padding: 5, size: 8 }) do
              cells.borders = %i[left right]
              rows(0).borders = %i[top bottom left right]
              rows(-1).borders = %i[bottom left right]
              column(1).align = :right
            end
          else
            pdf.text 'No copay charges due.', size: 10
          end

          pdf.move_down 20

          debts = debts_service[:debts]

          if debts.any?
            table_data = [['Benefits Overpayment', 'AMOUNT DUE', '']]
            table_data << [{ content: BENEFITS_TABLE_DESCRIPTION, inline_format: true }, '', '']
            debts.each_with_index do |debt, debt_index|
              line_number = debt_index + 1
              table_data << [
                "#{line_number}.  #{debt['benefitType']}" || '',
                "$#{format_amount(debt['currentAR'] || 0)}", # Plain string
                ''
              ]
            end

            total_debts = debts.sum { |d| (d['currentAR'] || 0).to_f }
            formatted_debt_total = "$#{format_amount(total_debts)}"
            table_data << [DEBT_TOTAL_TEXT, formatted_debt_total, '']
            table_data << [{ content: DEBT_PAYMENT_INSTRUCTIONS, inline_format: true }, '', '']
            pdf.table(table_data, width: pdf.bounds.width, cell_style: { padding: 5, size: 8 }) do
              cells.borders = %i[left right]
              row(0).columns(0).style(font_style: :bold_italic)
              rows(0).borders = %i[top bottom left right]
              rows(-1).borders = %i[bottom left right]
              rows(-2).columns(0).align = :right
              column(1).align = :right
            end
          else
            pdf.text 'No overpayments due.', size: 10
          end
        end.render

        legalese_pdf = load_legalese_pdf
        combined_pdf = CombinePDF.parse(debt_letter_pdf) << legalese_pdf

        combined_pdf.to_pdf
      end

      # rubocop:enable Metrics/MethodLength

      def combine_pdfs(document)
        legalese_pdf = load_legalese_pdf
        combined_pdf = CombinePDF.parse(document.read) << legalese_pdf
        combined_pdf.to_pdf
      end

      def save_pdf(filename = default_filename)
        save_pdf_content(filename, get_pdf)
        filename
      end

      private

      def copay_table_item(description, detail)
        [
          { content: description, inline_format: true } || '',
          "$#{format_amount(detail['pDTransAmt'] || 0)}",
          detail['pDRefNo'] || ''
        ]
      end

      def copays_amount_due(copays)
        total_copays = copays.sum { |c| c['pHAmtDue'] }
        "$#{format_amount(total_copays)}"
      end

      def format_amount(amount)
        format('%.2f', amount || 0.0)
      end

      def add_copay_description(detail, index, copay_index)
        indentation = Prawn::Text::NBSP * 6 # 6 non-breaking spaces
        sanitized_description = detail['pDTransDescOutput'].gsub(/&nbsp;|\s+/, ' ').strip
        index.zero? ? "#{copay_index + 1}.   #{sanitized_description}" : "#{indentation}#{sanitized_description}"
      end

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
            address_line_two: @user.address[:street2] || '',
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
        File.binwrite(path, content)
      end

      def load_legalese_pdf
        legalese_path = Rails.root.join(
          'modules', 'debts_api', 'app', 'assets', 'documents', 'one_debt_letter_legal_content.pdf'
        )

        CombinePDF.load(legalese_path)
      end

      def debts_service
        DebtManagementCenter::DebtsService.new(@user).get_debts
      end

      def copays_service
        MedicalCopays::VBS::Service.build(user: @user).get_copays
      end
    end
  end
end
