# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va21674v2'

describe PdfFill::Forms::Formatters::Va21674v2 do
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

    xcontext 'with large numbers' do
      let(:parent_object) do
        {
          'earnings_from_all_employment' => '12345678.90'
        }
      end

      it 'handles large numbers correctly' do
        result = split_earnings

        expect(result['earnings_from_all_employment']).to eq({
                                                               'first' => '12345',
                                                               'second' => '678',
                                                               'third' => '90'
                                                             })
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
end
