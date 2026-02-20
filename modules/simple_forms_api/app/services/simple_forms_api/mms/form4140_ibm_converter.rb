module SimpleFormsApi
  module Mms
    module Form4140IbmConverter
      FORM_TYPE_LABEL = '21-4140'.freeze

		  MAPPINGS = {
		    'VETERAN_FIRST_NAME' => ->(form) { form.first_name.to_s },
		    'VETERAN_INITIAL'    => ->(form) { form.middle_initial.to_s[0].to_s },
		    'VETERAN_LAST_NAME'  => ->(form) { form.last_name.to_s },
		    'VETERAN_NAME'       => ->(form) { full_name(form) },

		    'VETERAN_SSN'   => ->(form) { normalize_ssn(form.ssn) },
		    'VA_FILE_NUMBER' => ->(form) { form.data.dig('id_number', 'va_file_number').to_s },
		    'VETERAN_DOB'    => ->(form) { format_date(form.dob) },

		    'EMAIL'        => ->(form) { form.data['email_address'].to_s.downcase },
		    'PHONE_NUMBER' => ->(form) { normalize_phone(form.phone_primary) },

		    'VETERAN_ADDRESS_LINE1' => ->(form) { form.address.address_line1.to_s },
		    'VETERAN_ADDRESS_LINE2' => ->(form) { form.address.address_line2.to_s },
		    'VETERAN_ADDRESS_CITY'  => ->(form) { form.address.city.to_s },
		    'VETERAN_ADDRESS_STATE' => ->(form) { form.address.state_code.to_s },
		    'VETERAN_ADDRESS_COUNTRY' => ->(form) { form.address.country_code_iso2.to_s },
		    'VETERAN_ADDRESS_ZIP5' => ->(form) { normalize_zip(form.address.zip_code) },

		    'EMPLOYER_NAME_ADDRESS' => ->(form) { form.employment_history[0]&.name_and_address.to_s },

		    'VETERAN_SIGNATURE' => ->(form) { form.signature_employed || form.signature_unemployed || '' },

		    'DATE_SIGNED' => ->(form) { format_date(form.signature_date_employed || form.signature_date_unemployed) },

		    'FORM_TYPE'   => ->(_) { FORM_TYPE_LABEL },
		    'FORM_TYPE_1' => ->(_) { FORM_TYPE_LABEL }
		  }.freeze

      def self.convert(form)
        MAPPINGS.transform_values { |proc| proc.call(form) }.sort.to_h
      end

      # ---------- Helpers ----------
      def self.full_name(form)
        [form.first_name, form.middle_initial, form.last_name].compact.join(' ').strip
      end

      def self.normalize_ssn(ssn_array)
        ssn_array&.join&.gsub(/\D/, '') || ''
      end

      def self.normalize_phone(phone)
        phone.to_s.gsub(/\D/, '')
      end

      def self.normalize_zip(zip)
        zip.to_s.gsub(/\D/, '')[0, 5]
      end

			def self.format_date(date)
			  return '' if date.blank?

			  if date.is_a?(Array)
			    date = date.join('-') # "1979-02-27"
			  end

			  Date.parse(date.to_s).strftime('%m%d%Y')
			rescue ArgumentError
			  ''
			end
    end
  end
end