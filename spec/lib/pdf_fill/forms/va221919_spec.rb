# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va221919'

describe PdfFill::Forms::Va221919 do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/22-1919/kitchen_sink')
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields(nil) }

    context 'with complete form data' do
      let(:form_data) do
        {
          'certifyingOfficial' => {
            'first' => 'John',
            'last' => 'Doe',
            'role' => {
              'level' => 'certifying official'
            }
          },
          'institutionDetails' => {
            'institutionName' => 'Test University',
            'facilityCode' => '12345678',
            'institutionAddress' => {
              'street' => '123 Main St',
              'city' => 'Springfield',
              'state' => 'VA',
              'postalCode' => '22150'
            }
          },
          'isProprietaryProfit' => true,
          'isProfitConflictOfInterest' => false,
          'allProprietaryConflictOfInterest' => true,
          'proprietaryProfitConflicts' => [
            {
              'affiliatedIndividuals' => {
                'first' => 'Alice',
                'last' => 'Anderson',
                'title' => 'Administrator',
                'individualAssociationType' => 'va'
              }
            },
            {
              'affiliatedIndividuals' => {
                'first' => 'Bob',
                'last' => 'Baker',
                'title' => 'Director',
                'individualAssociationType' => 'saa'
              }
            }
          ],
          'allProprietaryProfitConflicts' => [
            {
              'certifyingOfficial' => {
                'first' => 'Carol',
                'last' => 'Clark',
                'title' => 'President'
              },
              'fileNumber' => '123456789',
              'enrollmentPeriod' => {
                'from' => '2024-01-01',
                'to' => '2024-12-31'
              }
            },
            {
              'certifyingOfficial' => {
                'first' => 'David',
                'last' => 'Davis',
                'title' => 'VP Academic Affairs'
              },
              'fileNumber' => '987654321',
              'enrollmentPeriod' => {
                'from' => '2023-08-01',
                'to' => '2024-05-31'
              }
            }
          ],
          'statementOfTruthSignature' => 'John Doe',
          'dateSigned' => '2024-01-15'
        }
      end

      it 'processes all form data correctly' do
        result = merged_fields

        # Check certifying official processing
        expect(result['certifyingOfficial']['fullName']).to eq('John Doe')
        expect(result['certifyingOfficial']['role']['displayRole']).to eq('certifying official')

        # Check boolean conversions
        expect(result['isProprietaryProfit']).to eq('YES')
        expect(result['isProfitConflictOfInterest']).to eq('NO')
        expect(result['allProprietaryConflictOfInterest']).to eq('YES')

        # Check proprietary conflicts processing (max 2)
        expect(result['proprietaryProfitConflicts0']).to eq({
                                                              'employeeName' => 'Alice Anderson',
                                                              'association' => 'VA'
                                                            })
        expect(result['proprietaryProfitConflicts1']).to eq({
                                                              'employeeName' => 'Bob Baker',
                                                              'association' => 'SAA'
                                                            })

        # Check all proprietary conflicts processing (max 2)
        expect(result['allProprietaryProfitConflicts0']).to eq({
                                                                 'officialName' => 'Carol Clark',
                                                                 'fileNumber' => '123456789',
                                                                 'enrollmentDateRange' => '2024-01-01',
                                                                 'enrollmentDateRangeEnd' => '2024-12-31'
                                                               })
        expect(result['allProprietaryProfitConflicts1']).to eq({
                                                                 'officialName' => 'David Davis',
                                                                 'fileNumber' => '987654321',
                                                                 'enrollmentDateRange' => '2023-08-01',
                                                                 'enrollmentDateRangeEnd' => '2024-05-31'
                                                               })

        # Check that original data is preserved
        expect(result['institutionDetails']['institutionName']).to eq('Test University')
        expect(result['statementOfTruthSignature']).to eq('John Doe')
        expect(result['dateSigned']).to eq('2024-01-15')
      end
    end

    context 'with minimal form data' do
      let(:form_data) do
        {
          'institutionDetails' => {
            'institutionName' => 'Minimal School'
          }
        }
      end

      it 'handles missing optional fields gracefully' do
        result = merged_fields

        # Check boolean fields default to N/A when nil
        expect(result['isProprietaryProfit']).to eq('N/A')
        expect(result['isProfitConflictOfInterest']).to eq('N/A')
        expect(result['allProprietaryConflictOfInterest']).to eq('N/A')

        # Check that missing sections don't cause errors
        expect(result['institutionDetails']['institutionName']).to eq('Minimal School')
      end
    end
  end

  describe 'private helper methods' do
    let(:test_form_data) { {} }
    let(:test_form_class) { described_class.new(test_form_data) }

    describe '#process_certifying_official' do
      it 'combines first and last name into fullName' do
        form_data = {
          'certifyingOfficial' => {
            'first' => 'Jane',
            'last' => 'Smith'
          }
        }

        test_form_class.send(:process_certifying_official, form_data)

        expect(form_data['certifyingOfficial']['fullName']).to eq('Jane Smith')
      end

      it 'sets displayRole when role level is not other' do
        form_data = {
          'certifyingOfficial' => {
            'first' => 'John',
            'last' => 'Doe',
            'role' => {
              'level' => 'certifying official'
            }
          }
        }

        test_form_class.send(:process_certifying_official, form_data)

        expect(form_data['certifyingOfficial']['role']['displayRole']).to eq('certifying official')
      end

      it 'sets displayRole to other value when role level is other' do
        form_data = {
          'certifyingOfficial' => {
            'first' => 'John',
            'last' => 'Doe',
            'role' => {
              'level' => 'other',
              'other' => 'Custom Title'
            }
          }
        }

        test_form_class.send(:process_certifying_official, form_data)

        expect(form_data['certifyingOfficial']['role']['displayRole']).to eq('Custom Title')
      end

      it 'handles missing names gracefully' do
        form_data = {
          'certifyingOfficial' => {
            'first' => 'John'
            # missing 'last'
          }
        }

        expect { test_form_class.send(:process_certifying_official, form_data) }.not_to raise_error
      end

      it 'handles missing certifying official' do
        form_data = {}

        expect { test_form_class.send(:process_certifying_official, form_data) }.not_to raise_error
      end

      it 'handles missing role' do
        form_data = {
          'certifyingOfficial' => {
            'first' => 'John',
            'last' => 'Doe'
          }
        }

        test_form_class.send(:process_certifying_official, form_data)

        expect(form_data['certifyingOfficial']['fullName']).to eq('John Doe')
      end
    end

    describe '#convert_boolean_fields' do
      it 'converts boolean values to YES/NO/N/A' do
        form_data = {
          'isProprietaryProfit' => true,
          'isProfitConflictOfInterest' => false,
          'allProprietaryConflictOfInterest' => nil
        }

        test_form_class.send(:convert_boolean_fields, form_data)

        expect(form_data['isProprietaryProfit']).to eq('YES')
        expect(form_data['isProfitConflictOfInterest']).to eq('NO')
        expect(form_data['allProprietaryConflictOfInterest']).to eq('N/A')
      end
    end

    describe '#process_proprietary_conflicts' do
      it 'processes up to 2 proprietary conflicts' do
        form_data = {
          'proprietaryProfitConflicts' => [
            {
              'affiliatedIndividuals' => {
                'first' => 'Alice',
                'last' => 'Anderson',
                'individualAssociationType' => 'va'
              }
            },
            {
              'affiliatedIndividuals' => {
                'first' => 'Bob',
                'last' => 'Baker',
                'individualAssociationType' => 'saa'
              }
            },
            {
              'affiliatedIndividuals' => {
                'first' => 'Charlie',
                'last' => 'Clark',
                'individualAssociationType' => 'other'
              }
            }
          ]
        }

        test_form_class.send(:process_proprietary_conflicts, form_data)

        expect(form_data['proprietaryProfitConflicts0']).to eq({
                                                                 'employeeName' => 'Alice Anderson',
                                                                 'association' => 'VA'
                                                               })
        expect(form_data['proprietaryProfitConflicts1']).to eq({
                                                                 'employeeName' => 'Bob Baker',
                                                                 'association' => 'SAA'
                                                               })
        # Third conflict should not be processed
        expect(form_data['proprietaryProfitConflicts2']).to be_nil
      end

      it 'handles empty array' do
        form_data = {
          'proprietaryProfitConflicts' => []
        }

        expect { test_form_class.send(:process_proprietary_conflicts, form_data) }.not_to raise_error
      end

      it 'handles missing proprietaryProfitConflicts' do
        form_data = {}

        expect { test_form_class.send(:process_proprietary_conflicts, form_data) }.not_to raise_error
      end

      it 'handles nil individualAssociationType' do
        form_data = {
          'proprietaryProfitConflicts' => [
            {
              'affiliatedIndividuals' => {
                'first' => 'Alice',
                'last' => 'Anderson',
                'individualAssociationType' => nil
              }
            }
          ]
        }

        test_form_class.send(:process_proprietary_conflicts, form_data)

        expect(form_data['proprietaryProfitConflicts0']['association']).to be_nil
      end
    end

    describe '#process_all_proprietary_conflicts' do
      it 'processes up to 2 all proprietary conflicts' do
        form_data = {
          'allProprietaryProfitConflicts' => [
            {
              'certifyingOfficial' => {
                'first' => 'Carol',
                'last' => 'Clark'
              },
              'fileNumber' => '123456789',
              'enrollmentPeriod' => {
                'from' => '2024-01-01',
                'to' => '2024-12-31'
              }
            },
            {
              'certifyingOfficial' => {
                'first' => 'David',
                'last' => 'Davis'
              },
              'fileNumber' => '987654321',
              'enrollmentPeriod' => {
                'from' => '2023-08-01',
                'to' => '2024-05-31'
              }
            },
            {
              'certifyingOfficial' => {
                'first' => 'Eve',
                'last' => 'Evans'
              },
              'fileNumber' => '555666777',
              'enrollmentPeriod' => {
                'from' => '2022-01-01',
                'to' => '2022-12-31'
              }
            }
          ]
        }

        test_form_class.send(:process_all_proprietary_conflicts, form_data)

        expect(form_data['allProprietaryProfitConflicts0']).to eq({
                                                                    'officialName' => 'Carol Clark',
                                                                    'fileNumber' => '123456789',
                                                                    'enrollmentDateRange' => '2024-01-01',
                                                                    'enrollmentDateRangeEnd' => '2024-12-31'
                                                                  })
        expect(form_data['allProprietaryProfitConflicts1']).to eq({
                                                                    'officialName' => 'David Davis',
                                                                    'fileNumber' => '987654321',
                                                                    'enrollmentDateRange' => '2023-08-01',
                                                                    'enrollmentDateRangeEnd' => '2024-05-31'
                                                                  })
        # Third conflict should not be processed
        expect(form_data['allProprietaryProfitConflicts2']).to be_nil
      end

      it 'handles empty array' do
        form_data = {
          'allProprietaryProfitConflicts' => []
        }

        expect { test_form_class.send(:process_all_proprietary_conflicts, form_data) }.not_to raise_error
      end

      it 'handles missing allProprietaryProfitConflicts' do
        form_data = {}

        expect { test_form_class.send(:process_all_proprietary_conflicts, form_data) }.not_to raise_error
      end
    end

    describe '#convert_boolean_to_yes_no' do
      it 'converts true to YES' do
        result = test_form_class.send(:convert_boolean_to_yes_no, true)
        expect(result).to eq('YES')
      end

      it 'converts false to NO' do
        result = test_form_class.send(:convert_boolean_to_yes_no, false)
        expect(result).to eq('NO')
      end

      it 'converts nil to N/A' do
        result = test_form_class.send(:convert_boolean_to_yes_no, nil)
        expect(result).to eq('N/A')
      end
    end
  end

  describe 'KEY mapping validation' do
    it 'has valid KEY structure' do
      expect(described_class::KEY).to be_a(Hash)
      expect(described_class::KEY).to be_frozen
    end

    it 'has proper question numbering' do
      question_nums = []
      extract_question_nums = lambda do |hash|
        hash.each_value do |value|
          if value.is_a?(Hash)
            if value[:question_num]
              question_nums << value[:question_num]
            else
              extract_question_nums.call(value)
            end
          end
        end
      end

      extract_question_nums.call(described_class::KEY)

      # Check that question numbers are sequential starting from 1
      expect(question_nums.sort).to eq((1..question_nums.length).to_a)
    end

    it 'has proper limit values for key fields' do
      # Institution name should have reasonable limit
      institution_name_config = described_class::KEY.dig('institutionDetails', 'institutionName')
      expect(institution_name_config[:limit]).to be > 50

      # Certifying official name should have reasonable limit
      certifying_official_config = described_class::KEY.dig('certifyingOfficial', 'fullName')
      expect(certifying_official_config[:limit]).to be > 30
    end
  end

  describe 'edge case handling' do
    let(:edge_case_form_data) { {} }
    let(:edge_case_form_class) { described_class.new(edge_case_form_data) }

    it 'handles completely empty form data' do
      result = edge_case_form_class.merge_fields(nil)

      expect(result['isProprietaryProfit']).to eq('N/A')
      expect(result['isProfitConflictOfInterest']).to eq('N/A')
      expect(result['allProprietaryConflictOfInterest']).to eq('N/A')
    end

    it 'handles single conflict entry' do
      form_data = {
        'proprietaryProfitConflicts' => [
          {
            'affiliatedIndividuals' => {
              'first' => 'Single',
              'last' => 'Entry',
              'individualAssociationType' => 'va'
            }
          }
        ]
      }

      form_class = described_class.new(form_data)
      result = form_class.merge_fields(nil)

      expect(result['proprietaryProfitConflicts0']).to eq({
                                                            'employeeName' => 'Single Entry',
                                                            'association' => 'VA'
                                                          })
      expect(result['proprietaryProfitConflicts1']).to be_nil
    end

    it 'handles associations with mixed case' do
      form_data = {
        'proprietaryProfitConflicts' => [
          {
            'affiliatedIndividuals' => {
              'first' => 'Mixed',
              'last' => 'Case',
              'individualAssociationType' => 'VaLue'
            }
          }
        ]
      }

      form_class = described_class.new(form_data)
      result = form_class.merge_fields(nil)

      expect(result['proprietaryProfitConflicts0']['association']).to eq('VALUE')
    end
  end
end
