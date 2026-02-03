# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va21674v2'

RSpec.describe PdfFill::Forms::Formatters::Va21674v2 do
  # Shared contexts for test data
  shared_context 'with sample earnings data' do
    let(:sample_earnings) do
      {
        'earnings_from_all_employment' => '12345.00',
        'annual_social_security_payments' => '6789.50',
        'other_annuities_income' => '999.99',
        'all_other_income' => '1234.56'
      }
    end

    let(:overflowing_earnings) do
      {
        'earnings_from_all_employment' => '123456789.00',
        'annual_social_security_payments' => '6789.50',
        'other_annuities_income' => '123456789.99',
        'all_other_income' => '1234.56'
      }
    end
  end

  shared_context 'with sample networth data' do
    let(:sample_networth) do
      {
        'savings' => '5000.00',
        'securities' => '3000.00',
        'real_estate' => '150000.00',
        'other_assets' => '2000.00',
        'total_value' => '160000.00'
      }
    end

    let(:overflowing_networth) do
      {
        'savings' => '12345678901.23',
        'securities' => '987654.32',
        'real_estate' => '55566677889.99',
        'other_assets' => '111222.33',
        'total_value' => '99999999999.88'
      }
    end
  end

  shared_context 'with form data structure' do
    let(:base_form_data) do
      {
        'dependents_application' => {
          'student_information' => [
            {
              'student_expected_earnings_next_year' => expected_earnings,
              'student_earnings_from_school_year' => current_earnings,
              'student_networth_information' => networth_info
            }
          ]
        }
      }
    end
  end

  # Shared examples for common test patterns
  shared_examples 'handles nil and blank inputs' do |method_name|
    it 'returns nil for nil input' do
      expect(described_class.send(method_name, nil)).to be_nil
    end

    it 'returns nil for empty hash' do
      expect(described_class.send(method_name, {})).to be_nil
    end
  end

  shared_examples 'overflow checker' do |fields_to_check|
    it 'returns false for values within limits' do
      result = described_class.send(subject_method, within_limit_data)
      fields_to_check.each do |field|
        expect(result[field]).to be false
      end
    end

    it 'returns true for values exceeding limits' do
      result = described_class.send(subject_method, exceeding_limit_data)
      expected_overflows.each do |field, should_overflow|
        expect(result[field]).to eq(should_overflow)
      end
    end

    it 'returns false for nil and blank values' do
      result = described_class.send(subject_method, mixed_data)
      fields_to_check.each do |field|
        expect(result[field]).to be false
      end
    end
  end

  shared_examples 'checkbox/radio formatter' do |return_on_value, return_off_value|
    it "returns '#{return_on_value}' when value is true" do
      expect(described_class.send(subject_method, true)).to eq(return_on_value)
    end

    it "returns #{return_off_value} when value is false" do
      expect(described_class.send(subject_method, false)).to eq(return_off_value)
    end

    it "returns '#{return_on_value}' when value is truthy" do
      expect(described_class.send(subject_method, 'yes')).to eq(return_on_value)
    end

    it "returns #{return_off_value} when value is falsy" do
      expect(described_class.send(subject_method, nil)).to eq(return_off_value)
    end
  end

  describe '.expand_phone_number' do
    subject(:expand_phone_number) { described_class.expand_phone_number(phone_number) }

    context 'with a standard 10-digit phone number' do
      let(:phone_number) { '1234567890' }

      it 'splits phone number into area code and number parts' do
        expect(expand_phone_number).to eq({
                                            'phone_area_code' => '123',
                                            'phone_first_three_numbers' => '456',
                                            'phone_last_four_numbers' => '7890'
                                          })
      end
    end

    context 'with a formatted phone number' do
      let(:phone_number) { '(123) 456-7890' }

      it 'strips formatting and splits phone number' do
        expect(expand_phone_number).to eq({
                                            'phone_area_code' => '123',
                                            'phone_first_three_numbers' => '456',
                                            'phone_last_four_numbers' => '7890'
                                          })
      end
    end

    context 'with a phone number containing spaces and dashes' do
      let(:phone_number) { '123 456-7890' }

      it 'strips all non-numeric characters and splits' do
        expect(expand_phone_number).to eq({
                                            'phone_area_code' => '123',
                                            'phone_first_three_numbers' => '456',
                                            'phone_last_four_numbers' => '7890'
                                          })
      end
    end

    context 'with a phone number with extra characters' do
      let(:phone_number) { '+1-123.456.7890 ext. 123' }

      it 'strips all non-numeric characters and uses first 10 digits' do
        expect(expand_phone_number).to eq({
                                            'phone_area_code' => '112',
                                            'phone_first_three_numbers' => '345',
                                            'phone_last_four_numbers' => '6789'
                                          })
      end
    end

    context 'with a short phone number' do
      let(:phone_number) { '123456' }

      it 'handles short numbers by using available digits' do
        expect(expand_phone_number).to eq({
                                            'phone_area_code' => '123',
                                            'phone_first_three_numbers' => '456',
                                            'phone_last_four_numbers' => ''
                                          })
      end
    end
  end

  describe '.get_program' do
    subject(:get_program) { described_class.get_program(parent_object) }

    context 'with valid program types' do
      let(:parent_object) do
        {
          'ch35' => true,
          'fry' => true
        }
      end

      it 'maps program types to readable names' do
        expect(get_program).to eq('Chapter 35, Fry Scholarship')
      end
    end

    context 'with a single program type' do
      let(:parent_object) { { 'feca' => true } }

      it 'returns single program name' do
        expect(get_program).to eq('FECA')
      end
    end

    context 'with other program type' do
      let(:parent_object) { { 'other' => true } }

      it 'returns other benefit' do
        expect(get_program).to eq('Other Benefit')
      end
    end

    context 'with false values' do
      let(:parent_object) do
        {
          'ch35' => true,
          'fry' => false,
          'feca' => nil,
          'other' => ''
        }
      end

      it 'filters out false values and returns only true programs' do
        expect(get_program).to eq('Chapter 35')
      end
    end

    context 'with blank object' do
      let(:parent_object) { {} }

      it 'returns nil for empty object' do
        expect(get_program).to be_nil
      end
    end

    context 'with nil object' do
      let(:parent_object) { nil }

      it 'returns nil for nil object' do
        expect(get_program).to be_nil
      end
    end

    context 'with all false values' do
      let(:parent_object) do
        {
          'ch35' => false,
          'fry' => false,
          'feca' => nil,
          'other' => ''
        }
      end

      it 'returns nil when all values are false or blank' do
        expect(get_program).to eq('')
      end
    end
  end

  describe '.split_earnings' do
    subject(:split_earnings) { described_class.split_earnings(parent_object) }

    context 'with earnings data' do
      let(:parent_object) do
        {
          'earnings_from_all_employment' => '123.45',
          'annual_social_security_payments' => '7890.12',
          'other_annuities_income' => '33456.78',
          'all_other_income' => '12345.00'
        }
      end

      it 'splits monetary values into formatted parts' do
        result = split_earnings

        expect(result['earnings_from_all_employment']).to eq({
                                                               'first' => '00',
                                                               'second' => '123',
                                                               'third' => '45'
                                                             })

        expect(result['annual_social_security_payments']).to eq({
                                                                  'first' => '07',
                                                                  'second' => '890',
                                                                  'third' => '12'
                                                                })

        expect(result['other_annuities_income']).to eq({
                                                         'first' => '33',
                                                         'second' => '456',
                                                         'third' => '78'
                                                       })

        expect(result['all_other_income']).to eq({
                                                   'first' => '12',
                                                   'second' => '345',
                                                   'third' => '00'
                                                 })
      end
    end

    context 'with large numbers' do
      let(:parent_object) do
        {
          'earnings_from_all_employment' => '12345678.90'
        }
      end

      it 'leaves the value as is' do
        result = split_earnings

        expect(result['earnings_from_all_employment']).to eq('12345678.90')
      end
    end

    context 'with small numbers' do
      let(:parent_object) do
        {
          'earnings_from_all_employment' => '00.99',
          'other_annuities_income' => '00.09',
          'all_other_income' => '26.00'
        }
      end

      it 'pads small numbers correctly' do
        result = split_earnings

        expect(result['earnings_from_all_employment']).to eq({
                                                               'first' => '00',
                                                               'second' => '000',
                                                               'third' => '99'
                                                             })
        expect(result['other_annuities_income']).to eq({
                                                         'first' => '00',
                                                         'second' => '000',
                                                         'third' => '09'
                                                       })
        expect(result['all_other_income']).to eq({
                                                   'first' => '00',
                                                   'second' => '026',
                                                   'third' => '00'
                                                 })
      end
    end

    context 'with blank and large values' do
      let(:parent_object) do
        {
          'earnings_from_all_employment' => '12345.00',
          'annual_social_security_payments' => '',
          'other_annuities_income' => '123456.78',
          'all_other_income' => '78901'
        }
      end

      it 'skips blank values, values over 8 characters, and processes valid ones' do
        result = split_earnings

        expect(result['earnings_from_all_employment']).to eq({
                                                               'first' => '12',
                                                               'second' => '345',
                                                               'third' => '00'
                                                             })

        expect(result['annual_social_security_payments']).to eq('')
        expect(result['other_annuities_income']).to eq('123456.78')

        expect(result['all_other_income']).to eq({
                                                   'first' => '78',
                                                   'second' => '901',
                                                   'third' => '00'
                                                 })
      end
    end

    context 'with nil object' do
      let(:parent_object) { nil }

      it 'returns nil for nil object' do
        expect(split_earnings).to be_nil
      end
    end

    context 'with empty object' do
      let(:parent_object) { {} }

      it 'returns nil for empty object' do
        expect(split_earnings).to be_nil
      end
    end
  end

  describe '.split_networth_information' do
    subject(:split_networth_information) { described_class.split_networth_information(parent_object) }

    context 'with networth data' do
      let(:parent_object) do
        {
          'savings' => '3456789.10',
          'securities' => '9.00',
          'real_estate' => '99.09',
          'other_assets' => '9999.99'
        }
      end

      it 'splits monetary values into formatted parts for networth' do
        result = split_networth_information

        expect(result['savings']).to eq({
                                          'first' => '3',
                                          'second' => '456',
                                          'third' => '789',
                                          'last' => '10'
                                        })

        expect(result['securities']).to eq({
                                             'first' => '0',
                                             'second' => '000',
                                             'third' => '009',
                                             'last' => '00'
                                           })

        expect(result['real_estate']).to eq({
                                              'first' => '0',
                                              'second' => '000',
                                              'third' => '099',
                                              'last' => '09'
                                            })

        expect(result['other_assets']).to eq({
                                               'first' => '0',
                                               'second' => '009',
                                               'third' => '999',
                                               'last' => '99'
                                             })
      end
    end

    context 'with blank values' do
      let(:parent_object) do
        {
          'savings' => '99999.00',
          'securities' => '',
          'real_estate' => '11234567.89',
          'other_assets' => '909909.00'
        }
      end

      it 'skips blank values, values over 10 characters, and processes valid ones' do
        result = split_networth_information

        expect(result['savings']).to eq({
                                          'first' => '0',
                                          'second' => '099',
                                          'third' => '999',
                                          'last' => '00'
                                        })

        expect(result['securities']).not_to be_present
        expect(result['real_estate']).to eq('11234567.89')

        expect(result['other_assets']).to eq({
                                               'first' => '0',
                                               'second' => '909',
                                               'third' => '909',
                                               'last' => '00'
                                             })
      end
    end

    context 'with nil object' do
      let(:parent_object) { nil }

      it 'returns nil for nil object' do
        expect(split_networth_information).to be_nil
      end
    end

    context 'with empty object' do
      let(:parent_object) { {} }

      it 'returns nil for empty object' do
        expect(split_networth_information).to be_nil
      end
    end
  end

  describe '.format_checkboxes' do
    subject(:format_checkboxes) { described_class.format_checkboxes(dependents_application) }

    let(:dependents_application) do
      {
        'student_information' => [
          {
            'was_married' => true,
            'tuition_is_paid_by_gov_agency' => false,
            'school_information' => {
              'student_is_enrolled_full_time' => true,
              'student_did_attend_school_last_term' => false,
              'is_school_accredited' => true
            }
          },
          {
            'was_married' => false,
            'tuition_is_paid_by_gov_agency' => true,
            'school_information' => {
              'student_is_enrolled_full_time' => false,
              'student_did_attend_school_last_term' => true,
              'is_school_accredited' => false
            }
          }
        ]
      }
    end

    it 'formats all checkbox fields for multiple students' do
      format_checkboxes

      student1 = dependents_application['student_information'][0]
      student2 = dependents_application['student_information'][1]

      # First student
      expect(student1['was_married']).to eq({
                                              'was_married_yes' => 'On',
                                              'was_married_no' => nil
                                            })

      expect(student1['tuition_is_paid_by_gov_agency']).to eq({
                                                                'is_paid_yes' => nil,
                                                                'is_paid_no' => 'On'
                                                              })

      expect(student1['school_information']['student_is_enrolled_full_time']).to eq({
                                                                                      'full_time_yes' => 'On',
                                                                                      'full_time_no' => nil
                                                                                    })

      expect(student1['school_information']['student_did_attend_school_last_term']).to eq({
                                                                                            'did_attend_yes' => nil,
                                                                                            'did_attend_no' => 'On'
                                                                                          })

      expect(student1['school_information']['is_school_accredited']).to eq({
                                                                             'is_school_accredited_yes' => 0,
                                                                             'is_school_accredited_no' => nil
                                                                           })

      # Second student
      expect(student2['was_married']).to eq({
                                              'was_married_yes' => nil,
                                              'was_married_no' => 'On'
                                            })

      expect(student2['tuition_is_paid_by_gov_agency']).to eq({
                                                                'is_paid_yes' => 'On',
                                                                'is_paid_no' => nil
                                                              })

      expect(student2['school_information']['student_is_enrolled_full_time']).to eq({
                                                                                      'full_time_yes' => nil,
                                                                                      'full_time_no' => 'On'
                                                                                    })

      expect(student2['school_information']['student_did_attend_school_last_term']).to eq({
                                                                                            'did_attend_yes' => 'On',
                                                                                            'did_attend_no' => nil
                                                                                          })

      expect(student2['school_information']['is_school_accredited']).to eq({
                                                                             'is_school_accredited_yes' => nil,
                                                                             'is_school_accredited_no' => 0
                                                                           })
    end

    context 'with no student information' do
      let(:dependents_application) { {} }

      it 'does not raise an error' do
        expect { format_checkboxes }.not_to raise_error
      end
    end

    context 'with empty student information array' do
      let(:dependents_application) { { 'student_information' => [] } }

      it 'does not raise an error' do
        expect { format_checkboxes }.not_to raise_error
      end
    end

    context 'with nil student information' do
      let(:dependents_application) { { 'student_information' => nil } }

      it 'does not raise an error' do
        expect { format_checkboxes }.not_to raise_error
      end
    end
  end

  describe '.check_earnings_overflow' do
    subject(:check_earnings_overflow) { described_class.check_earnings_overflow(student_earnings) }

    context 'with earnings within character limits' do
      let(:student_earnings) do
        {
          'earnings_from_all_employment' => '12345.00',
          'annual_social_security_payments' => '6789.50',
          'other_annuities_income' => '999.99',
          'all_other_income' => '1234.56'
        }
      end

      it 'returns all false values for overflow' do
        expect(check_earnings_overflow).to eq({
                                                earnings_from_all_employment: false,
                                                annual_social_security_payments: false,
                                                other_annuities_income: false,
                                                all_other_income: false
                                              })
      end
    end

    context 'with earnings exceeding character limits' do
      let(:student_earnings) do
        {
          'earnings_from_all_employment' => '123456789.00',
          'annual_social_security_payments' => '6789.50',
          'other_annuities_income' => '123456789.99',
          'all_other_income' => '1234.56'
        }
      end

      it 'returns true for fields exceeding limit' do
        expect(check_earnings_overflow).to eq({
                                                earnings_from_all_employment: true,
                                                annual_social_security_payments: false,
                                                other_annuities_income: true,
                                                all_other_income: false
                                              })
      end
    end

    context 'with nil and blank values' do
      let(:student_earnings) do
        {
          'earnings_from_all_employment' => nil,
          'annual_social_security_payments' => '',
          'other_annuities_income' => '999.99',
          'all_other_income' => {}
        }
      end

      it 'returns false for nil and blank values' do
        expect(check_earnings_overflow).to eq({
                                                earnings_from_all_employment: false,
                                                annual_social_security_payments: false,
                                                other_annuities_income: false,
                                                all_other_income: false
                                              })
      end
    end
  end

  describe '.check_networth_overflow' do
    subject(:check_networth_overflow) { described_class.check_networth_overflow(student_networth) }

    context 'with networth within character limits' do
      let(:student_networth) do
        {
          'savings' => '1234567.89',
          'securities' => '987654.32',
          'real_estate' => '555666.77',
          'other_assets' => '111222.33',
          'total_value' => '9999999.99'
        }
      end

      it 'returns all false values for overflow' do
        expect(check_networth_overflow).to eq({
                                                savings: false,
                                                securities: false,
                                                real_estate: false,
                                                other_assets: false,
                                                total_value: false
                                              })
      end
    end

    context 'with networth exceeding character limits' do
      let(:student_networth) do
        {
          'savings' => '12345678901.23',
          'securities' => '987654.32',
          'real_estate' => '55566677889.99',
          'other_assets' => '111222.33',
          'total_value' => '99999999999.88'
        }
      end

      it 'returns true for fields exceeding limit' do
        expect(check_networth_overflow).to eq({
                                                savings: true,
                                                securities: false,
                                                real_estate: true,
                                                other_assets: false,
                                                total_value: true
                                              })
      end
    end

    context 'with nil and blank values' do
      let(:student_networth) do
        {
          'savings' => nil,
          'securities' => '',
          'real_estate' => '555666.77',
          'other_assets' => {},
          'total_value' => nil
        }
      end

      it 'returns false for nil and blank values' do
        expect(check_networth_overflow).to eq({
                                                savings: false,
                                                securities: false,
                                                real_estate: false,
                                                other_assets: false,
                                                total_value: false
                                              })
      end
    end
  end

  describe '.check_for_single_overflow' do
    subject(:check_for_single_overflow) { described_class.check_for_single_overflow(data, size) }

    context 'when data is a string within size limit' do
      let(:data) { 'test123' }
      let(:size) { 8 }

      it 'returns false' do
        expect(check_for_single_overflow).to be false
      end
    end

    context 'when data is a string exceeding size limit' do
      let(:data) { '123456789' }
      let(:size) { 8 }

      it 'returns true' do
        expect(check_for_single_overflow).to be true
      end
    end

    context 'when data is exactly at size limit' do
      let(:data) { '12345678' }
      let(:size) { 8 }

      it 'returns false' do
        expect(check_for_single_overflow).to be false
      end
    end

    context 'when data is a hash' do
      let(:data) { { 'key' => 'value' } }
      let(:size) { 5 }

      it 'returns false' do
        expect(check_for_single_overflow).to be false
      end
    end

    context 'when data is nil' do
      let(:data) { nil }
      let(:size) { 5 }

      it 'returns false' do
        expect(check_for_single_overflow).to be false
      end
    end

    context 'when data is blank string' do
      let(:data) { '' }
      let(:size) { 5 }

      it 'returns false' do
        expect(check_for_single_overflow).to be false
      end
    end
  end

  describe '.select_checkbox' do
    let(:subject_method) { :select_checkbox }
    let(:value) { nil } # This will be overridden by shared examples

    it_behaves_like 'checkbox/radio formatter', 'On', nil
  end

  describe '.select_radio_button' do
    let(:subject_method) { :select_radio_button }
    let(:value) { nil } # This will be overridden by shared examples

    it_behaves_like 'checkbox/radio formatter', 0, nil
  end

  describe '.handle_overflows' do
    subject(:handle_overflows) { described_class.handle_overflows(form_data) }

    let(:form_data) do
      {
        'dependents_application' => {
          'student_information' => [
            {
              'student_expected_earnings_next_year' => expected_earnings,
              'student_earnings_from_school_year' => current_earnings,
              'student_networth_information' => networth_info
            }
          ]
        }
      }
    end

    context 'when no student information exists' do
      let(:form_data) { { 'dependents_application' => {} } }

      it 'returns without error' do
        expect { handle_overflows }.not_to raise_error
      end
    end

    context 'when student information is empty' do
      let(:form_data) do
        {
          'dependents_application' => {
            'student_information' => []
          }
        }
      end

      it 'returns without error' do
        expect { handle_overflows }.not_to raise_error
      end
    end

    context 'with earnings that overflow' do
      let(:expected_earnings) do
        {
          'earnings_from_all_employment' => '123456789.00',
          'annual_social_security_payments' => '6789.50',
          'other_annuities_income' => '999.99',
          'all_other_income' => '1234.56'
        }
      end
      let(:current_earnings) do
        {
          'earnings_from_all_employment' => '5000.00',
          'annual_social_security_payments' => '123456789.00',
          'other_annuities_income' => '999.99',
          'all_other_income' => '1234.56'
        }
      end
      let(:networth_info) do
        {
          'savings' => '5000.00',
          'securities' => '3000.00',
          'real_estate' => '15000000000.00',
          'other_assets' => '2000.00',
          'total_value' => '15000010000.00'
        }
      end

      it 'handles all overflow scenarios' do
        handle_overflows

        # Check expected earnings overflow
        expect(form_data['student_expected_earnings_next_year_overflow']['earnings_from_all_employment'])
          .to eq('123456789.00')

        student_info = form_data['dependents_application']['student_information'][0]
        expected_earnings = student_info['student_expected_earnings_next_year']
        expect(expected_earnings['earnings_from_all_employment'])
          .to eq({ 'first' => 'Se', 'second' => 'e a', 'third' => 'dd' })

        # Check current earnings overflow
        expect(form_data['student_earnings_from_school_year_overflow']['annual_social_security_payments'])
          .to eq('123456789.00')

        current_earnings = student_info['student_earnings_from_school_year']
        expect(current_earnings['annual_social_security_payments'])
          .to eq({ 'first' => 'Se', 'second' => 'e a', 'third' => 'dd' })

        # Check networth overflow
        expect(form_data['student_networth_information_overflow']['real_estate'])
          .to eq('15000000000.00')

        networth_info = student_info['student_networth_information']
        expect(networth_info['real_estate'])
          .to eq({ 'first' => 'S', 'second' => 'ee ', 'third' => 'add', 'last' => "'l" })

        expect(form_data['student_networth_information_overflow']['total_value'])
          .to eq('15000010000.00')
        expect(networth_info['total_value'])
          .to eq({ 'first' => 'S', 'second' => 'ee ', 'third' => 'add', 'last' => "'l" })
      end
    end

    context 'with no overflows' do
      let(:expected_earnings) do
        {
          'earnings_from_all_employment' => '5000.00',
          'annual_social_security_payments' => '6789.50',
          'other_annuities_income' => '999.99',
          'all_other_income' => '1234.56'
        }
      end
      let(:current_earnings) do
        {
          'earnings_from_all_employment' => '5000.00',
          'annual_social_security_payments' => '7000.00',
          'other_annuities_income' => '999.99',
          'all_other_income' => '1234.56'
        }
      end
      let(:networth_info) do
        {
          'savings' => '5000.00',
          'securities' => '3000.00',
          'real_estate' => '150000.00',
          'other_assets' => '2000.00',
          'total_value' => '160000.00'
        }
      end

      it 'does not create overflow fields' do
        handle_overflows

        expect(form_data['student_expected_earnings_next_year_overflow']).to be_nil
        expect(form_data['student_earnings_from_school_year_overflow']).to be_nil
        expect(form_data['student_networth_information_overflow']).to be_nil
      end
    end
  end

  describe '.handle_earnings_overflow' do
    subject(:handle_earnings_overflow) do
      described_class.handle_earnings_overflow(form_data, student_earnings, form_key)
    end

    let(:form_data) do
      {
        'dependents_application' => {
          'student_information' => [
            {
              form_key => student_earnings
            }
          ]
        }
      }
    end
    let(:form_key) { 'student_expected_earnings_next_year' }

    context 'when earnings have overflow' do
      let(:student_earnings) do
        {
          'earnings_from_all_employment' => '123456789.00',
          'annual_social_security_payments' => '6789.50',
          'other_annuities_income' => '999.99',
          'all_other_income' => '123456789.99'
        }
      end

      it 'creates overflow data and updates original fields' do
        handle_earnings_overflow

        overflow_key = "#{form_key}_overflow"
        expect(form_data[overflow_key]['earnings_from_all_employment']).to eq('123456789.00')
        expect(form_data[overflow_key]['all_other_income']).to eq('123456789.99')

        student_info = form_data['dependents_application']['student_information'][0][form_key]
        expect(student_info['earnings_from_all_employment']).to eq({
                                                                     'first' => 'Se',
                                                                     'second' => 'e a',
                                                                     'third' => 'dd'
                                                                   })
        expect(student_info['all_other_income']).to eq({
                                                         'first' => 'Se',
                                                         'second' => 'e a',
                                                         'third' => 'dd'
                                                       })
      end
    end

    context 'when earnings have no overflow' do
      let(:student_earnings) do
        {
          'earnings_from_all_employment' => '5000.00',
          'annual_social_security_payments' => '6789.50',
          'other_annuities_income' => '999.99',
          'all_other_income' => '1234.56'
        }
      end

      it 'does not create overflow data' do
        handle_earnings_overflow

        overflow_key = "#{form_key}_overflow"
        expect(form_data[overflow_key]).to be_nil
      end
    end
  end

  describe '.handle_networth_overflow' do
    subject(:handle_networth_overflow) do
      described_class.handle_networth_overflow(form_data, student_networth)
    end

    let(:form_data) do
      {
        'dependents_application' => {
          'student_information' => [
            {
              'student_networth_information' => student_networth
            }
          ]
        }
      }
    end

    context 'when networth has overflow' do
      let(:student_networth) do
        {
          'savings' => '12345678901.23',
          'securities' => '987654.32',
          'real_estate' => '55566677889.99',
          'other_assets' => '111222.33',
          'total_value' => '99999999999.88'
        }
      end

      it 'creates overflow data and updates original fields' do
        handle_networth_overflow

        expect(form_data['student_networth_information_overflow']['savings']).to eq('12345678901.23')
        expect(form_data['student_networth_information_overflow']['real_estate']).to eq('55566677889.99')
        expect(form_data['student_networth_information_overflow']['total_value']).to eq('99999999999.88')

        student_info = form_data['dependents_application']['student_information'][0]
        student_networth_info = student_info['student_networth_information']
        expect(student_networth_info['savings']).to eq({
                                                         'first' => 'S',
                                                         'second' => 'ee ',
                                                         'third' => 'add',
                                                         'last' => "'l"
                                                       })
        expect(student_networth_info['real_estate']).to eq({
                                                             'first' => 'S',
                                                             'second' => 'ee ',
                                                             'third' => 'add',
                                                             'last' => "'l"
                                                           })
        expect(student_networth_info['total_value']).to eq({
                                                             'first' => 'S',
                                                             'second' => 'ee ',
                                                             'third' => 'add',
                                                             'last' => "'l"
                                                           })
      end
    end

    context 'when networth has no overflow' do
      let(:student_networth) do
        {
          'savings' => '5000.00',
          'securities' => '3000.00',
          'real_estate' => '150000.00',
          'other_assets' => '2000.00',
          'total_value' => '160000.00'
        }
      end

      it 'does not create overflow data' do
        handle_networth_overflow

        expect(form_data['student_networth_information_overflow']).to be_nil
      end
    end
  end
end
