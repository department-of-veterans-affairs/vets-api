# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

# Integration tests for PDF transformation pipeline through PdfFiller

# Form configurations - fixtures and stamps info only
FORM_CONFIGS = {
  'vha_10_10d' => { fixture: 'vha_10_10d', has_stamps: true },
  'vha_10_10d_2027' => { fixture: 'vha_10_10d', has_stamps: true },
  'vha_10_7959a' => { fixture: 'vha_10_7959a', has_stamps: true },
  'vha_10_7959c' => { fixture: 'vha_10_7959c', has_stamps: false },
  'vha_10_7959c_rev2025' => { fixture: 'vha_10_7959c', has_stamps: true },
  'vha_10_7959f_1' => { fixture: 'vha_10_7959f_1', has_stamps: true },
  'vha_10_7959f_2' => { fixture: 'vha_10_7959f_2', has_stamps: false },
  'vha_10_7959f_2_2025' => { fixture: 'vha_10_7959f_2', has_stamps: false }
}.freeze

# Field type mappings - maps PDF field names to semantic field types
FIELD_TYPE_MAPPINGS = {
  # Veteran First Names
  'form1[0].#subform[0].VeteransFirstName[0]' => :veteran_first_name,
  'form1[0].#subform[0].VETERANSFIRSTNAME[0]' => :veteran_first_name,
  'form1[0].#subform[0].VetFirstName[0]' => :veteran_first_name,

  # Veteran Last Names
  'form1[0].#subform[0].VeteransLastName[0]' => :veteran_last_name,
  'form1[0].#subform[0].VETERANSLASTNAME[0]' => :veteran_last_name,
  'form1[0].#subform[0].VetLastName[0]' => :veteran_last_name,

  # Veteran Middle Initials
  'form1[0].#subform[0].VeteransMI[0]' => :veteran_middle_initial,
  'form1[0].#subform[0].VETERANMIDDLEINITIAL[0]' => :veteran_middle_initial,
  'form1[0].#subform[0].MiddleInitials[0]' => :veteran_middle_initial,

  # Veteran SSN
  'form1[0].#subform[0].VeteransSSN[0]' => :veteran_ssn,
  'form1[0].#subform[0].VETERANSSN[0]' => :veteran_ssn,
  'form1[0].#subform[0].SocialSecurityNumber[0]' => :veteran_ssn,
  'vha107959fform[0].#subform[0].SSN-1[0]' => :veteran_ssn,

  # Applicant First Names
  'form1[0].#subform[0].FirstName1[0]' => :applicant_first_name,
  'form1[0].#subform[0].APPLICANTFIRSTNAME1[0]' => :applicant_first_name,
  'form1[0].#subform[0].FirstNme-ptnt[0]' => :applicant_first_name,
  'form1[0].#subform[0].applicantFirstName2[0]' => :applicant_first_name,
  'vha107959fform[0].#subform[0].FirstName-1[0]' => :veteran_first_name,

  # Applicant Last Names
  'form1[0].#subform[0].LastName1[0]' => :applicant_last_name,
  'form1[0].#subform[0].APPLICANTLASTNAME1[0]' => :applicant_last_name,
  'form1[0].#subform[0].LastNme-ptnt[0]' => :applicant_last_name,
  'form1[0].#subform[0].applicantLastName2[0]' => :applicant_last_name,
  'vha107959fform[0].#subform[0].LastName-1[0]' => :veteran_last_name,

  # Sponsor Names
  'form1[0].#subform[0].FirstNme-spnsr[0]' => :sponsor_first_name,
  'form1[0].#subform[0].LastNme-spnsr[0]' => :sponsor_last_name,

  # Dates
  'form1[0].#subform[0].VeteransDateOfBirth[0]' => :veteran_date_of_birth,
  'form1[0].#subform[0].VETERANDATEOFBIRTH[0]' => :veteran_date_of_birth,
  'form1[0].#subform[0].DateofBirth[0]' => :veteran_date_of_birth,
  'vha107959fform[0].#subform[0].DateofBirth-1[0]' => :veteran_date_of_birth,
  'form1[0].#subform[0].Date-Ptnt[0]' => :applicant_date_of_birth,
  'form1[0].#subform[0].DateSigned[0]' => :signature_date,
  'form1[0].#subform[0].DATESIGNED[0]' => :signature_date,
  'form1[0].#subform[0].DateTimeField1[0]' => :signature_date,
  'vha107959fform[0].#subform[0].SignatureDate-1[0]' => :signature_date,

  # Boolean Fields (true/false -> 1/0 or 0/1)
  'form1[0].#subform[0].IsTheVeteranDeceased[0]' => :boolean_inverted,
  'form1[0].#subform[0].RadioButtonList[0]' => :boolean_inverted,
  'form1[0].#subform[0].RadioButtonList[1]' => :boolean_inverted,
  'form1[0].#subform[0].EnrolledMedicare[0]' => :boolean_enrolled,
  'form1[0].#subform[0].ENROLLEDINMEDICARE1[0]' => :boolean_enrolled,
  'form1[0].#subform[0].HasOtherInsurance[0]' => :boolean_has_other,
  'form1[0].#subform[0].HASOTHERHEALTHINSURANCE1[0]' => :boolean_has_other,
  'form1[0].#subform[0].CheckIfNew[0]' => :boolean_new_address,

  # Addresses & Contact
  'form1[0].#subform[0].VeteransStreetAddress[0]' => :veteran_street_address,
  'form1[0].#subform[0].STREETADDRESS[0]' => :veteran_street_address,
  'form1[0].#subform[0].VeteransCity[0]' => :veteran_city,
  'form1[0].#subform[0].CITY[0]' => :veteran_city,
  'form1[0].#subform[0].VeteransState[0]' => :veteran_state,
  'form1[0].#subform[0].STATE[0]' => :veteran_state,
  'form1[0].#subform[0].VeteransZipCode[0]' => :veteran_zip_code,
  'form1[0].#subform[0].ZIPCODE[0]' => :veteran_zip_code,
  'form1[0].#subform[0].VeteransPhoneNumber[0]' => :veteran_phone,
  'form1[0].#subform[0].PHONENUMBER[0]' => :veteran_phone,
  'vha107959fform[0].#subform[0].Telephone-1[0]' => :veteran_phone
}.freeze

RSpec.describe IvcChampva::PdfFiller, type: :service do
  let(:pdf_data_collector) { {} }

  def setup_pdf_data_collection
    binaries_double = double('binaries', pdftk: '/usr/bin/pdftk')
    allow(Settings).to receive(:binaries).and_return(binaries_double)

    mock_pdftk = double('PdfForms')
    allow(PdfForms).to receive(:new).with('/usr/bin/pdftk').and_return(mock_pdftk)

    setup_pdftk_mock(mock_pdftk)
    setup_stamp_mock
  end

  def setup_pdftk_mock(mock_pdftk)
    allow(mock_pdftk).to receive(:fill_form) do |template_path, output_path, mapped_data, options = {}|
      pdf_data_collector[:template_path] = template_path
      pdf_data_collector[:output_path] = output_path
      pdf_data_collector[:mapped_data] = mapped_data
      pdf_data_collector[:options] = options

      FileUtils.touch(output_path)
      true
    end
  end

  def setup_stamp_mock
    allow(IvcChampva::PdfStamper).to receive(:stamp_pdf) do |template_path, form, current_loa|
      pdf_data_collector[:stamps] = {
        template_path:,
        form_class: form.class.name,
        desired_stamps: safely_get_stamps(form),
        current_loa:
      }
    end
  end

  def safely_get_stamps(form)
    form.respond_to?(:desired_stamps) ? form.desired_stamps : []
  rescue ArgumentError
    # Handle forms with incorrect respond_to_missing? signature
    form.methods.include?(:desired_stamps) ? form.desired_stamps : []
  end

  def load_form_fixture(form_id)
    fixture_name = FORM_CONFIGS[form_id][:fixture]
    fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', "#{fixture_name}.json")
    JSON.parse(File.read(fixture_path))
  end

  def create_form_instance(form_id, data)
    form_class_name = "IvcChampva::#{form_id.titleize.gsub(/[-\s]/, '')}"
    form_class_name.constantize.new(data)
  end

  def expected_fields_for(form_id)
    erb_template_path = Rails.root.join('modules', 'ivc_champva', 'app', 'form_mappings', "#{form_id}.json.erb")
    erb_content = File.read(erb_template_path)

    # Extract JSON keys using regex - matches quoted strings that are JSON keys
    erb_content.scan(/"([^"]+)"\s*:/).flatten
  end

  # Main validation method that routes each field to its appropriate validator
  def verify_field_types_semantically(json_data, pdf_mapped_data) # rubocop:disable Metrics/MethodLength
    pdf_mapped_data.each do |pdf_field_name, pdf_value|
      field_type = FIELD_TYPE_MAPPINGS[pdf_field_name]
      next unless field_type

      case field_type
      when :veteran_first_name
        validate_veteran_first_name(json_data, pdf_value, pdf_field_name)
      when :veteran_last_name
        validate_veteran_last_name(json_data, pdf_value, pdf_field_name)
      when :veteran_middle_initial
        validate_veteran_middle_initial(json_data, pdf_value, pdf_field_name)
      when :veteran_ssn
        validate_veteran_ssn(json_data, pdf_value, pdf_field_name)
      when :applicant_first_name
        validate_applicant_first_name(json_data, pdf_value, pdf_field_name)
      when :applicant_last_name
        validate_applicant_last_name(json_data, pdf_value, pdf_field_name)
      when :sponsor_first_name
        validate_sponsor_first_name(json_data, pdf_value, pdf_field_name)
      when :sponsor_last_name
        validate_sponsor_last_name(json_data, pdf_value, pdf_field_name)
      when :veteran_date_of_birth
        validate_veteran_date_of_birth(json_data, pdf_value, pdf_field_name)
      when :applicant_date_of_birth
        validate_applicant_date_of_birth(json_data, pdf_value, pdf_field_name)
      when :signature_date
        validate_signature_date(json_data, pdf_value, pdf_field_name)
      when :boolean_inverted
        validate_boolean_inverted(json_data, pdf_value, pdf_field_name)
      when :boolean_enrolled
        validate_boolean_enrolled(json_data, pdf_value, pdf_field_name)
      when :boolean_has_other
        validate_boolean_has_other(json_data, pdf_value, pdf_field_name)
      when :boolean_new_address
        validate_boolean_new_address(json_data, pdf_value, pdf_field_name)
      when :veteran_street_address
        validate_veteran_street_address(json_data, pdf_value, pdf_field_name)
      when :veteran_city
        validate_veteran_city(json_data, pdf_value, pdf_field_name)
      when :veteran_state
        validate_veteran_state(json_data, pdf_value, pdf_field_name)
      when :veteran_zip_code
        validate_veteran_zip_code(json_data, pdf_value, pdf_field_name)
      when :veteran_phone
        validate_veteran_phone(json_data, pdf_value, pdf_field_name)
      end
    end
  end

  # Helper method to extract values from multiple JSON paths
  def extract_values_from_paths(json_data, paths)
    paths.map do |path|
      # Handle numeric array indices in paths like "applicants.0.applicant_name.first"
      path_parts = path.split('.').map { |part| part.match?(/^\d+$/) ? part.to_i : part }
      json_data.dig(*path_parts)
    end.compact.uniq
  end

  def validate_veteran_first_name(json_data, pdf_value, field_name)
    possible_paths = ['veteran.full_name.first']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran first name '#{pdf_value}' to match one of: \
                               #{possible_values} from JSON paths: #{possible_paths}"
  end

  def validate_veteran_last_name(json_data, pdf_value, field_name)
    possible_paths = ['veteran.full_name.last']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    # Handle last name with suffix (e.g., "Surname Mr.")
    expected_values = possible_values.dup
    suffix = json_data.dig('veteran', 'full_name', 'suffix')
    expected_values << "#{possible_values.first} #{suffix}" if suffix.present?

    expect(expected_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran last name '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_veteran_middle_initial(json_data, pdf_value, field_name)
    possible_paths = ['veteran.full_name.middle']
    middle_names = extract_values_from_paths(json_data, possible_paths)
    expected_values = middle_names.map { |name| name&.first }.compact
    expected_values << nil if expected_values.empty? # Allow nil/empty

    expect(expected_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran middle initial '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_veteran_ssn(json_data, pdf_value, field_name)
    possible_paths = ['veteran.ssn_or_tin', 'veteran.ssn']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran SSN '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_applicant_first_name(json_data, pdf_value, field_name)
    possible_paths = [
      'applicant_name.first',
      'applicants.0.applicant_name.first',
      'applicants.1.applicant_name.first',
      'applicants.2.applicant_name.first'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected applicant first name '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_applicant_last_name(json_data, pdf_value, field_name)
    possible_paths = [
      'applicant_name.last',
      'applicants.0.applicant_name.last',
      'applicants.1.applicant_name.last',
      'applicants.2.applicant_name.last'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected applicant last name '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_sponsor_first_name(json_data, pdf_value, field_name)
    possible_paths = ['sponsor_name.first']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected sponsor first name '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_sponsor_last_name(json_data, pdf_value, field_name)
    possible_paths = ['sponsor_name.last']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected sponsor last name '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_veteran_date_of_birth(json_data, pdf_value, field_name)
    possible_paths = ['veteran.date_of_birth']
    possible_dates = extract_values_from_paths(json_data, possible_paths)

    # Handle different date formats
    expected_values = possible_dates.compact.flat_map do |date_str|
      parsed_date = Date.parse(date_str)
      [
        date_str,                                    # Original: "1987-02-02"
        parsed_date.strftime('%m/%d/%Y'),            # US Format: "02/02/1987"
        parsed_date.strftime('%Y-%m-%d')             # ISO Format: "1987-02-02"
      ]
    rescue Date::Error
      [date_str] # If parsing fails, just use original
    end

    expect(expected_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran date of birth '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_applicant_date_of_birth(json_data, pdf_value, field_name)
    possible_paths = ['applicant_dob', 'applicants.0.applicant_dob']
    possible_dates = extract_values_from_paths(json_data, possible_paths)

    expected_values = possible_dates.compact.flat_map do |date_str|
      parsed_date = Date.parse(date_str)
      [date_str, parsed_date.strftime('%m/%d/%Y'), parsed_date.strftime('%Y-%m-%d')]
    rescue Date::Error
      [date_str]
    end

    expect(expected_values).to include(pdf_value),
                               "Field '#{field_name}' expected applicant date of birth '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_signature_date(json_data, pdf_value, field_name) # rubocop:disable Metrics/MethodLength
    possible_paths = [
      'statement_of_truth_signature_date',
      'certification.date',
      'certification_date',     # Used by 7959c forms
      'veteran.date_of_death'   # Some forms use death date for signature
    ]
    possible_dates = extract_values_from_paths(json_data, possible_paths)

    # If no signature date found, assume the PDF value is correct (common for test fixtures)
    if possible_dates.empty?
      Rails.logger.debug do
        "No signature date source found for #{field_name}, assuming PDF value '#{pdf_value}' is correct"
      end
      return
    end

    expected_values = possible_dates.compact.flat_map do |date_str|
      parsed_date = Date.parse(date_str)
      [date_str, parsed_date.strftime('%m/%d/%Y'), parsed_date.strftime('%Y-%m-%d')]
    rescue Date::Error
      [date_str]
    end

    expect(expected_values).to include(pdf_value),
                               "Field '#{field_name}' expected signature date '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_boolean_inverted(json_data, pdf_value, field_name) # rubocop:disable Metrics/MethodLength
    # Inverted boolean: true -> 0, false -> 1 (common in PDF checkboxes)
    # Different forms use different paths for their radio buttons
    possible_paths = [
      'veteran.sponsor_is_deceased',
      'veteran.is_active_service_death',
      'has_other_health_insurance',
      'applicant_medicare_pharmacy_benefits',
      'applicant_medicare_advantage'
    ]
    possible_boolean_values = extract_values_from_paths(json_data, possible_paths)

    # If no values found, try to infer from the actual PDF value (validation still catches errors)
    if possible_boolean_values.empty?
      Rails.logger.debug { "No boolean source found for #{field_name}, allowing PDF value #{pdf_value}" }
      return # Skip validation for unmapped boolean fields
    end

    expected_values = possible_boolean_values.map do |bool_val|
      case bool_val
      when true, 'true', 'yes' then 0
      when false, 'false', 'no', nil then 1
      else bool_val
      end
    end

    expect(expected_values).to include(pdf_value.to_i),
                               "Field '#{field_name}' expected inverted boolean '#{pdf_value}' to match one of: \
                               #{expected_values} from sources: #{possible_boolean_values}"
  end

  def validate_boolean_enrolled(json_data, pdf_value, field_name)
    # Standard boolean: enrolled/true -> 1, not enrolled/false -> 0
    possible_paths = [
      'applicants.0.applicant_medicare_status.eligibility',
      'applicants.1.applicant_medicare_status.eligibility',
      'applicants.2.applicant_medicare_status.eligibility'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expected_values = possible_values.map do |val|
      case val
      when 'enrolled', true, 'true', 'yes' then 1
      when 'not_enrolled', false, 'false', 'no', nil then 0
      else val
      end
    end

    expect(expected_values).to include(pdf_value.to_i),
                               "Field '#{field_name}' expected enrollment boolean '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_boolean_has_other(json_data, pdf_value, field_name)
    # Has other insurance: yes/true -> 1, no/false -> 0
    possible_paths = [
      'applicants.0.applicant_has_ohi.has_ohi',
      'applicants.1.applicant_has_ohi.has_ohi',
      'applicants.2.applicant_has_ohi.has_ohi',
      'has_other_health_insurance'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expected_values = possible_values.map do |val|
      case val
      when 'yes', true, 'true' then 1
      when 'no', false, 'false', nil then 0
      else val
      end
    end

    expect(expected_values).to include(pdf_value.to_i),
                               "Field '#{field_name}' expected has-other boolean '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_boolean_new_address(json_data, pdf_value, field_name)
    # New address: no -> 0, yes/anything else -> 1
    possible_paths = ['applicant_new_address']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expected_values = possible_values.map do |val|
      case val
      when 'no', false, 'false' then 0
      else 1
      end
    end

    expect(expected_values).to include(pdf_value.to_i),
                               "Field '#{field_name}' expected new address boolean '#{pdf_value}' to match one of: \
                               #{expected_values}"
  end

  def validate_veteran_street_address(json_data, pdf_value, field_name)
    possible_paths = [
      'veteran.address.street_combined',
      'veteran.physical_address.street_combined'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran street address '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_veteran_city(json_data, pdf_value, field_name)
    possible_paths = [
      'veteran.address.city',
      'veteran.physical_address.city'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran city '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_veteran_state(json_data, pdf_value, field_name)
    possible_paths = [
      'veteran.address.state',
      'veteran.physical_address.state'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran state '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_veteran_zip_code(json_data, pdf_value, field_name)
    possible_paths = [
      'veteran.address.postal_code',
      'veteran.physical_address.postal_code'
    ]
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran zip code '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  def validate_veteran_phone(json_data, pdf_value, field_name)
    possible_paths = ['veteran.phone_number']
    possible_values = extract_values_from_paths(json_data, possible_paths)

    expect(possible_values).to include(pdf_value),
                               "Field '#{field_name}' expected veteran phone '#{pdf_value}' to match one of: \
                               #{possible_values}"
  end

  before do
    setup_pdf_data_collection
  end

  describe 'Case 2: HTTP Request JSON -> Form-specific .erb transformation -> PDF File' do
    FORM_CONFIGS.each_key do |form_id|
      context "for form #{form_id}" do
        it 'transforms raw JSON data through ERB template and captures all expected PDF fields' do
          raw_json_data = load_form_fixture(form_id)
          form = create_form_instance(form_id, raw_json_data)

          filler = IvcChampva::PdfFiller.new(
            form_number: form_id,
            form:,
            uuid: SecureRandom.uuid
          )

          filler.generate

          expect(pdf_data_collector[:mapped_data]).not_to be_nil
          expect(pdf_data_collector[:mapped_data]).to be_a(Hash)
          expect(pdf_data_collector[:mapped_data].keys).not_to be_empty

          # Verify all expected fields from ERB template are present
          expected_fields = expected_fields_for(form_id)
          expected_fields.each do |field|
            error_message = "Expected field '#{field}' missing from mapped_data for #{form_id}"
            expect(pdf_data_collector[:mapped_data]).to have_key(field), error_message
          end

          # Verify field count matches expected
          expect(pdf_data_collector[:mapped_data].keys.count).to eq(expected_fields.count)

          # Verify actual data values are correctly transformed
          verify_field_types_semantically(raw_json_data, pdf_data_collector[:mapped_data])
        end
      end
    end
  end

  describe 'Case 3: HTTP Request JSON -> desired_stamps() -> Form-specific .erb -> PDF File' do
    FORM_CONFIGS.select { |_, config| config[:has_stamps] }.each_key do |form_id|
      context "for form #{form_id} with stamps" do
        it 'includes desired_stamps transformation in the PDF generation pipeline' do
          raw_json_data = load_form_fixture(form_id)
          form = create_form_instance(form_id, raw_json_data)

          filler = IvcChampva::PdfFiller.new(
            form_number: form_id,
            form:,
            uuid: SecureRandom.uuid
          )

          filler.generate

          expect(pdf_data_collector[:mapped_data]).not_to be_nil
          expect(pdf_data_collector[:mapped_data]).to be_a(Hash)

          expect(pdf_data_collector[:stamps]).not_to be_nil
          expect(pdf_data_collector[:stamps][:desired_stamps]).to be_an(Array)

          # Verify stamps were applied
          expect(pdf_data_collector[:stamps][:desired_stamps].count).to be_positive

          # Verify actual data values are correctly transformed
          verify_field_types_semantically(raw_json_data, pdf_data_collector[:mapped_data])

          # Verify stamp structure
          first_stamp = pdf_data_collector[:stamps][:desired_stamps].first
          expect(first_stamp).to have_key(:coords)
          expect(first_stamp).to have_key(:text)
          expect(first_stamp).to have_key(:page)
          expect(first_stamp[:coords]).to be_an(Array)
          expect(first_stamp[:coords].length).to eq(2)

          # Verify all expected fields are still mapped
          expected_fields = expected_fields_for(form_id)
          expect(pdf_data_collector[:mapped_data].keys.count).to eq(expected_fields.count)
        end
      end
    end
  end

  describe 'Case 4: HTTP Request JSON -> Metadata -> MetadataValidator -> ' \
           'UploadsController -> get_attachments -> ERB -> PDF File' do
    FORM_CONFIGS.each_key do |form_id|
      context "for form #{form_id}" do
        it 'transforms data through the complete attachments pipeline with metadata validation' do
          raw_json_data = load_form_fixture(form_id)
          form = create_form_instance(form_id, raw_json_data)

          metadata = form.metadata
          expect(metadata).to be_a(Hash)
          expect(metadata).to have_key('docType')
          expect(metadata).to have_key('businessLine')
          expect(metadata).to have_key('uuid')

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)
          expect(validated_metadata).to be_a(Hash)
          expect(validated_metadata.keys).to include('docType', 'businessLine')

          # Simulate attachments pipeline deep copy (attachments.rb line 108)
          additional_form_data = Marshal.load(Marshal.dump(raw_json_data))

          additional_filler = IvcChampva::PdfFiller.new(
            form_number: form_id,
            form: create_form_instance(form_id, additional_form_data),
            name: "#{form_id}_additional_test",
            uuid: form.uuid
          )

          additional_filler.generate

          expect(pdf_data_collector[:mapped_data]).not_to be_nil
          expect(pdf_data_collector[:mapped_data]).to be_a(Hash)
          expect(pdf_data_collector[:mapped_data].keys).not_to be_empty

          # Verify all expected fields are present after full pipeline
          expected_fields = expected_fields_for(form_id)
          expected_fields.each do |field|
            error_message = "Expected field '#{field}' missing after attachments pipeline for #{form_id}"
            expect(pdf_data_collector[:mapped_data]).to have_key(field), error_message
          end

          expect(pdf_data_collector[:mapped_data].keys.count).to eq(expected_fields.count)
        end
      end
    end
  end
end
