# frozen_string_literal: true

require 'common/models/resource'

module VeteranEnrollmentSystem
  module Form1095B
    class Form1095B
      include Vets::Model

      attribute :first_name, String
      attribute :middle_name, String
      attribute :last_name, String
      attribute :last_4_ssn, String
      attribute :birth_date, Date
      attribute :address, String
      attribute :city, String
      attribute :state, String
      attribute :province, String
      attribute :country, String
      attribute :zip_code, String
      attribute :foreign_zip, String
      attribute :is_corrected, Bool, default: false
      attribute :coverage_months, Array
      attribute :tax_year, String

      def txt_file
        template_path = self.class.txt_template_path(tax_year)
        unless File.exist?(template_path)
          Rails.logger.error "1095-B template for year #{tax_year} does not exist."
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: "1095-B for tax year #{tax_year} not supported", source: self.class.name
          )
        end

        template_data = attributes.merge(txt_form_data)
        File.open(template_path, 'r') do |template_file|
          template_file.read % template_data.symbolize_keys
        end
      end

      def pdf_file
        template_path = self.class.pdf_template_path(tax_year)
        unless File.exist?(template_path) && respond_to?("pdf_#{tax_year}_attributes", true)
          Rails.logger.error "1095-B template for year #{tax_year} does not exist."
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: "1095-B for tax year #{tax_year} not supported", source: self.class.name
          )
        end

        pdftk = PdfForms.new(Settings.binaries.pdftk)
        tmp_file = Tempfile.new("1095B-#{SecureRandom.hex}.pdf")
        generate_pdf(pdftk, tmp_file, template_path)
      end

      class << self
        # there is some overlap in the data provided by coveredIndividual and responsibleIndividual.
        # in the VA enrollment system, they are always the same.
        def parse(form_data)
          prepared_data = {
            first_name: form_data['data']['coveredIndividual']['name']['firstName'],
            middle_name: form_data['data']['coveredIndividual']['name']['middleName'],
            last_name: form_data['data']['coveredIndividual']['name']['lastName'],
            last_4_ssn: form_data['data']['coveredIndividual']['ssn']&.last(4).presence,
            birth_date: form_data['data']['coveredIndividual']['dateOfBirth'],
            address: form_data['data']['responsibleIndividual']['address']['street1'],
            city: form_data['data']['responsibleIndividual']['address']['city'],
            state: form_data['data']['responsibleIndividual']['address']['stateOrProvince'],
            province: form_data['data']['responsibleIndividual']['address']['stateOrProvince'],
            country: form_data['data']['responsibleIndividual']['address']['country'],
            zip_code: form_data['data']['responsibleIndividual']['address']['zipOrPostalCode'],
            foreign_zip: form_data['data']['responsibleIndividual']['address']['zipOrPostalCode'],
            is_corrected: false, # this will always be false at this time
            coverage_months: coverage_months(form_data),
            tax_year: form_data['data']['taxYear']
          }
          new(prepared_data)
        end

        def available_years(periods)
          years = periods.each_with_object([]) do |period, array|
            start_date = period['startDate'].to_date.year
            # if no end date, the user is still enrolled
            end_date = period['endDate']&.to_date&.year || Date.current.year
            array << start_date
            array << end_date
            if (end_date - start_date) > 1
              intervening_years = (start_date..end_date).to_a
              array.concat(intervening_years)
            end
          end.uniq.sort
          years.filter { |year| year.between?(*available_years_range) }
        end

        def available_years_range
          current_tax_year = Date.current.year - 1
          # using a range of years because more years of form data will be available in the future
          [current_tax_year, current_tax_year]
        end

        def pdf_template_path(year)
          "lib/veteran_enrollment_system/form1095_b/templates/pdfs/1095b-#{year}.pdf"
        end

        def txt_template_path(year)
          "lib/veteran_enrollment_system/form1095_b/templates/txts/1095b-#{year}.txt"
        end

        private

        def coverage_months(form_data)
          months = form_data['data']['coveredIndividual']['monthsCovered']
          coverage_months = Date::MONTHNAMES.compact.map { |month| months&.include?(month.upcase) ? month.upcase : false }
          covered_all = form_data['data']['coveredIndividual']['coveredAll12Months']
          [covered_all, *coverage_months]
        end
      end

      private

      def country_and_zip
        "#{country} #{zip_code || foreign_zip}"
      end

      def middle_initial
        middle_name ? middle_name[0] : ''
      end

      def birthdate_unless_ssn
        last_4_ssn.present? ? '' : birth_date.strftime('%m/%d/%Y')
      end

      def full_name
        [first_name, middle_name.presence, last_name].compact.join(' ')
      end

      def name_with_middle_initial
        [first_name, middle_initial.presence, last_name].compact.join(' ')
      end

      def txt_form_data
        text_data = {
          birth_date_field: birthdate_unless_ssn,
          state_or_province: state || province,
          country_and_zip:,
          full_name:,
          name_with_middle_initial:,
          corrected: is_corrected ? 'X' : '--'
        }

        coverage_months.each_with_index do |val, i|
          field_name = "coverage_month_#{i}"
          text_data[field_name.to_sym] = val ? 'X' : '--'
        end

        text_data
      end

      def generate_pdf(pdftk, tmp_file, template_path)
        pdftk.fill_form(
          template_path,
          tmp_file,
          pdf_data,
          flatten: true
        )
        ret_pdf = tmp_file.read

        tmp_file.close
        tmp_file.unlink

        ret_pdf
      end

      # rubocop:disable Metrics/MethodLength
      def pdf_data
        year_specific_attributes = send("pdf_#{tax_year}_attributes")
        {
          'topmostSubform[0].Page1[0].Pg1Header[0].cb_1[1]': is_corrected && 2,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_10[0]': 'C',
          'topmostSubform[0].Page1[0].f1_18[0]': 'US Department of Veterans Affairs',
          'topmostSubform[0].Page1[0].f1_19[0]': '74-1612229',
          'topmostSubform[0].Page1[0].f1_20[0]': '877-222-8387',
          'topmostSubform[0].Page1[0].f1_21[0]': 'P.O. BOX 149975',
          'topmostSubform[0].Page1[0].f1_22[0]': 'Austin',
          'topmostSubform[0].Page1[0].f1_23[0]': 'TX',
          'topmostSubform[0].Page1[0].f1_24[0]': '78714-8957',
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_25[0]': first_name,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_26[0]': middle_initial,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_27[0]': last_name,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_28[0]': last_4_ssn || '',
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_29[0]': birthdate_unless_ssn,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_01[0]': coverage_months[0] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_02[0]': coverage_months[1] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_03[0]': coverage_months[2] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_04[0]': coverage_months[3] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_05[0]': coverage_months[4] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_06[0]': coverage_months[5] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_07[0]': coverage_months[6] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_08[0]': coverage_months[7] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_09[0]': coverage_months[8] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_10[0]': coverage_months[9] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_11[0]': coverage_months[10] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_12[0]': coverage_months[11] && 1,
          'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_13[0]': coverage_months[12] && 1
        }.merge(year_specific_attributes)
      end
      # rubocop:enable Metrics/MethodLength

      def pdf_2024_attributes
        {
          'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_01[0]': first_name,
          'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_02[0]': middle_name,
          'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_03[0]': last_name,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_04[0]': last_4_ssn || '',
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_05[0]': birthdate_unless_ssn,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_06[0]': address,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_07[0]': city,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_08[0]': state || province,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_09[0]': country_and_zip
        }
      end

      def pdf_2025_attributes
        {
          'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_1[0]': first_name,
          'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_2[0]': middle_name,
          'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_3[0]': last_name,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_4[0]': last_4_ssn || '',
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_5[0]': birthdate_unless_ssn,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_6[0]': address,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_7[0]': city,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_8[0]': state || province,
          'topmostSubform[0].Page1[0].Part1Contents[0].f1_9[0]': country_and_zip
        }
      end
    end
  end
end
