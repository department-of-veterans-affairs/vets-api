# frozen_string_literal: true

class Form1095B < ApplicationRecord
  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options

  validates :veteran_icn, :tax_year,  presence: true
  validates :veteran_icn, uniqueness: { scope: :tax_year }
  validate :proper_form_data_schema

  def txt_file
    unless File.exist?(txt_template_path)
      Rails.logger.error "1095-B template for year #{tax_year} does not exist."
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: "1095-B for tax year #{tax_year} not supported", source: self.class.name
      )
    end

    template_file = File.open(txt_template_path, 'r')

    rv = template_file.read % data.merge(txt_form_data)

    template_file.close

    rv
  end

  def pdf_file
    pdftk = PdfForms.new(Settings.binaries.pdftk)

    tmp_file = Tempfile.new("1095B-#{SecureRandom.hex}.pdf")

    unless File.exist?(pdf_template_path)
      Rails.logger.error "1095-B template for year #{tax_year} does not exist."
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: "1095-B for tax year #{tax_year} not supported", source: self.class.name
      )
    end

    generate_pdf(pdftk, tmp_file)
  end

  # we are currently restricting access to only the most recent tax year
  def self.current_tax_year
    Date.current.year - 1
  end

  private

  def pdf_template_path
    "lib/form1095_b/templates/pdfs/1095b-#{tax_year}.pdf"
  end

  def txt_template_path
    "lib/form1095_b/templates/txts/1095b-#{tax_year}.txt"
  end

  def country_and_zip
    "#{data[:country]} #{data[:zip_code] || data[:foreign_zip]}"
  end

  def middle_initial
    data[:middle_name] ? data[:middle_name][0] : ''
  end

  def birthdate_unless_ssn
    data[:last_4_ssn].present? ? '' : data[:birth_date]
  end

  def txt_form_data
    text_data = {
      birth_date_field: birthdate_unless_ssn,
      state_or_province: data[:state] || data[:province],
      country_and_zip:,
      middle_init: middle_initial,
      corrected: data[:is_corrected] ? 'X' : '--'
    }

    data[:coverage_months].each_with_index do |val, ndx|
      field_name = "coverage_month_#{ndx}"
      text_data[field_name.to_sym] = val ? 'X' : '--'
    end

    text_data
  end

  # rubocop:disable Metrics/MethodLength
  def generate_pdf(pdftk, tmp_file)
    pdftk.fill_form(
      pdf_template_path,
      tmp_file,
      {
        'topmostSubform[0].Page1[0].Pg1Header[0].cb_1[1]': data[:is_corrected] && 2,
        'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_01[0]': data[:first_name],
        'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_02[0]': data[:middle_name],
        'topmostSubform[0].Page1[0].Part1Contents[0].Line1[0].f1_03[0]': data[:last_name],
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_04[0]': data[:last_4_ssn] || '',
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_05[0]': birthdate_unless_ssn,
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_06[0]': data[:address],
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_07[0]': data[:city],
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_08[0]': data[:state] || data[:province],
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_09[0]': country_and_zip,
        'topmostSubform[0].Page1[0].Part1Contents[0].f1_10[0]': 'C',
        'topmostSubform[0].Page1[0].f1_18[0]': 'US Department of Veterans Affairs',
        'topmostSubform[0].Page1[0].f1_19[0]': '74-1612229',
        'topmostSubform[0].Page1[0].f1_20[0]': '877-222-8387',
        'topmostSubform[0].Page1[0].f1_21[0]': 'P.O. BOX 149975',
        'topmostSubform[0].Page1[0].f1_22[0]': 'Austin',
        'topmostSubform[0].Page1[0].f1_23[0]': 'TX',
        'topmostSubform[0].Page1[0].f1_24[0]': '78714-8957',
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_25[0]': data[:first_name],
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_26[0]': middle_initial,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_27[0]': data[:last_name],
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_28[0]': data[:last_4_ssn] || '',
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].f1_29[0]': birthdate_unless_ssn,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_01[0]': data[:coverage_months][0] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_02[0]': data[:coverage_months][1] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_03[0]': data[:coverage_months][2] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_04[0]': data[:coverage_months][3] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_05[0]': data[:coverage_months][4] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_06[0]': data[:coverage_months][5] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_07[0]': data[:coverage_months][6] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_08[0]': data[:coverage_months][7] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_09[0]': data[:coverage_months][8] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_10[0]': data[:coverage_months][9] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_11[0]': data[:coverage_months][10] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_12[0]': data[:coverage_months][11] && 1,
        'topmostSubform[0].Page1[0].Table1_Part4[0].Row23[0].c1_13[0]': data[:coverage_months][12] && 1
      },
      flatten: true
    )
    ret_pdf = tmp_file.read

    tmp_file.close
    tmp_file.unlink

    ret_pdf
  rescue PdfForms::PdftkError => e
    # in case theres other errors generating the PDF
    Rails.logger.error e.message
    raise
  end

  def form_data_schema
    {
      type: 'object',
      required: %w[first_name middle_name last_name address city country coverage_months],
      properties: {
        first_name: { type: 'string' },
        middle_name: { type: 'string' },
        last_name: { type: 'string' },
        last_4_ssn: {
          type: 'string',
          pattern: '[0-9]{4}|^$'
        },
        birth_date: {
          type: 'string',
          format: 'date'
        },
        address: { type: 'string' },
        city: { type: 'string' },
        state: { type: 'string' },
        province: { type: 'string' },
        country: { type: 'string' },
        zip_code: { type: 'string' },
        foreign_zip: { type: 'string' },
        is_beneficiary: { type: 'boolean' },
        is_corrected: { type: 'boolean' },
        coverage_months: {
          type: 'array',
          items: { type: 'boolean' },
          minItems: 13,
          maxItems: 13
        }
      }
    }
  end
  # rubocop:enable Metrics/MethodLength

  def data
    @data ||= JSON.parse(form_data, { symbolize_names: true })
  end

  def proper_form_data_schema
    JSON::Validator.validate!(form_data_schema, form_data)
  rescue JSON::Schema::ValidationError => e
    errors.add(:form_data, **e)
  end
end
