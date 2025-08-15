# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va221919'

describe PdfFill::Forms::Va221919 do
  let(:form_data) do
    JSON.parse(
      Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1919', 'minimal.json').read
    )
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields(nil) }

    it 'merges certifying official name correctly' do
      expect(merged_fields['certifyingOfficial']['fullName']).to eq('John Doe')
    end

    it 'sets display role correctly for standard role' do
      expect(merged_fields['certifyingOfficial']['role']['displayRole']).to eq('certifying official')
    end

    it 'converts boolean fields to YES/NO format' do
      expect(merged_fields['isProprietaryProfit']).to eq('YES')
      expect(merged_fields['isProfitConflictOfInterest']).to eq('YES')
      expect(merged_fields['allProprietaryConflictOfInterest']).to eq('YES')
    end

    it 'processes proprietary profit conflicts correctly' do
      expect(merged_fields['proprietaryProfitConflicts0']['employeeName']).to eq('Jane Smith')
      expect(merged_fields['proprietaryProfitConflicts0']['association']).to eq('VA')
      expect(merged_fields['proprietaryProfitConflicts1']['employeeName']).to eq('Bob Johnson')
      expect(merged_fields['proprietaryProfitConflicts1']['association']).to eq('SAA')
    end

    it 'processes all proprietary profit conflicts correctly' do
      expect(merged_fields['allProprietaryProfitConflicts0']['officialName']).to eq('Alice Williams')
      expect(merged_fields['allProprietaryProfitConflicts0']['fileNumber']).to eq('123456789')
      expect(merged_fields['allProprietaryProfitConflicts0']['enrollmentDateRange']).to eq('2023-01-01')
      expect(merged_fields['allProprietaryProfitConflicts0']['enrollmentDateRangeEnd']).to eq('2023-12-31')
    end

    it 'preserves institution details unchanged' do
      expect(merged_fields['institutionDetails']).to eq(form_data['institutionDetails'])
      expect(merged_fields['institutionDetails']['institutionName']).to eq('Test University')
      expect(merged_fields['institutionDetails']['facilityCode']).to eq('12345678')
      expect(merged_fields['institutionDetails']['institutionAddress']['street']).to eq('123 Main St')
    end

    it 'calls the correct helper methods in proper order' do
      form_instance = described_class.new(form_data)

      expect(form_instance).to receive(:process_certifying_official).once.and_call_original
      expect(form_instance).to receive(:convert_boolean_fields).once.and_call_original
      expect(form_instance).to receive(:process_proprietary_conflicts).once.and_call_original
      expect(form_instance).to receive(:process_all_proprietary_conflicts).once.and_call_original

      form_instance.merge_fields(nil)
    end

    it 'limits proprietary conflicts to maximum of 2' do
      form_data_with_many_conflicts = form_data.dup
      form_data_with_many_conflicts['proprietaryProfitConflicts'] = [
        form_data['proprietaryProfitConflicts'][0],
        form_data['proprietaryProfitConflicts'][1],
        {
          'affiliatedIndividuals' => {
            'first' => 'Third',
            'last' => 'Person',
            'title' => 'Manager',
            'individualAssociationType' => 'va'
          }
        }
      ]

      form_class_many = described_class.new(form_data_with_many_conflicts)
      merged = form_class_many.merge_fields(nil)

      expect(merged['proprietaryProfitConflicts0']).to be_present
      expect(merged['proprietaryProfitConflicts1']).to be_present
      expect(merged['proprietaryProfitConflicts2']).to be_nil
    end

    it 'limits all proprietary conflicts to maximum of 2' do
      form_data_with_many_conflicts = form_data.dup
      form_data_with_many_conflicts['allProprietaryProfitConflicts'] = [
        form_data['allProprietaryProfitConflicts'][0],
        form_data['allProprietaryProfitConflicts'][1],
        {
          'certifyingOfficial' => {
            'first' => 'Third',
            'last' => 'Official',
            'title' => 'Manager'
          },
          'fileNumber' => '555555555',
          'enrollmentPeriod' => {
            'from' => '2021-01-01',
            'to' => '2021-12-31'
          }
        }
      ]

      form_class_many = described_class.new(form_data_with_many_conflicts)
      merged = form_class_many.merge_fields(nil)

      expect(merged['allProprietaryProfitConflicts0']).to be_present
      expect(merged['allProprietaryProfitConflicts1']).to be_present
      expect(merged['allProprietaryProfitConflicts2']).to be_nil
    end

    context 'when role is other' do
      let(:form_data_with_other_role) do
        data = form_data.dup
        data['certifyingOfficial']['role'] = {
          'level' => 'other',
          'other' => 'Custom Role'
        }
        data
      end

      let(:form_class_other) { described_class.new(form_data_with_other_role) }

      it 'uses the other field value for display role' do
        merged = form_class_other.merge_fields(nil)
        expect(merged['certifyingOfficial']['role']['displayRole']).to eq('Custom Role')
      end
    end

    context 'when boolean fields are false' do
      let(:form_data_false) do
        data = form_data.dup
        data['isProprietaryProfit'] = false
        data['isProfitConflictOfInterest'] = false
        data['allProprietaryConflictOfInterest'] = false
        data
      end

      let(:form_class_false) { described_class.new(form_data_false) }

      it 'converts false values to NO' do
        merged = form_class_false.merge_fields(nil)
        expect(merged['isProprietaryProfit']).to eq('NO')
        expect(merged['isProfitConflictOfInterest']).to eq('NO')
        expect(merged['allProprietaryConflictOfInterest']).to eq('NO')
      end
    end

    context 'when boolean fields are nil' do
      let(:form_data_nil) do
        data = form_data.dup
        data['isProprietaryProfit'] = nil
        data['isProfitConflictOfInterest'] = nil
        data['allProprietaryConflictOfInterest'] = nil
        data
      end

      let(:form_class_nil) { described_class.new(form_data_nil) }

      it 'converts nil values to N/A' do
        merged = form_class_nil.merge_fields(nil)
        expect(merged['isProprietaryProfit']).to eq('N/A')
        expect(merged['isProfitConflictOfInterest']).to eq('N/A')
        expect(merged['allProprietaryConflictOfInterest']).to eq('N/A')
      end
    end
  end

  # Unit tests for refactored helper methods
  describe 'private helper methods' do
    let(:form_instance) { described_class.new(form_data) }

    describe '#process_certifying_official' do
      it 'combines first and last name into fullName' do
        test_data = { 'certifyingOfficial' => { 'first' => 'Jane', 'last' => 'Smith' } }
        form_instance.send(:process_certifying_official, test_data)

        expect(test_data['certifyingOfficial']['fullName']).to eq('Jane Smith')
      end

      it 'sets displayRole to level when level is not other' do
        test_data = {
          'certifyingOfficial' => {
            'first' => 'Jane',
            'last' => 'Smith',
            'role' => { 'level' => 'registrar' }
          }
        }
        form_instance.send(:process_certifying_official, test_data)

        expect(test_data['certifyingOfficial']['role']['displayRole']).to eq('registrar')
      end

      it 'sets displayRole to other value when level is other' do
        test_data = {
          'certifyingOfficial' => {
            'first' => 'Jane',
            'last' => 'Smith',
            'role' => { 'level' => 'other', 'other' => 'Custom Title' }
          }
        }
        form_instance.send(:process_certifying_official, test_data)

        expect(test_data['certifyingOfficial']['role']['displayRole']).to eq('Custom Title')
      end

      it 'does nothing when certifyingOfficial is missing' do
        test_data = {}
        expect { form_instance.send(:process_certifying_official, test_data) }.not_to raise_error
        expect(test_data['certifyingOfficial']).to be_nil
      end

      it 'handles missing first or last name gracefully' do
        test_data = { 'certifyingOfficial' => { 'first' => 'Jane' } }
        form_instance.send(:process_certifying_official, test_data)

        expect(test_data['certifyingOfficial']['fullName']).to be_nil
      end

      it 'handles missing role gracefully' do
        test_data = { 'certifyingOfficial' => { 'first' => 'Jane', 'last' => 'Smith' } }
        expect { form_instance.send(:process_certifying_official, test_data) }.not_to raise_error
      end
    end

    describe '#convert_boolean_fields' do
      it 'converts true values to YES' do
        test_data = {
          'isProprietaryProfit' => true,
          'isProfitConflictOfInterest' => true,
          'allProprietaryConflictOfInterest' => true
        }
        form_instance.send(:convert_boolean_fields, test_data)

        expect(test_data['isProprietaryProfit']).to eq('YES')
        expect(test_data['isProfitConflictOfInterest']).to eq('YES')
        expect(test_data['allProprietaryConflictOfInterest']).to eq('YES')
      end

      it 'converts false values to NO' do
        test_data = {
          'isProprietaryProfit' => false,
          'isProfitConflictOfInterest' => false,
          'allProprietaryConflictOfInterest' => false
        }
        form_instance.send(:convert_boolean_fields, test_data)

        expect(test_data['isProprietaryProfit']).to eq('NO')
        expect(test_data['isProfitConflictOfInterest']).to eq('NO')
        expect(test_data['allProprietaryConflictOfInterest']).to eq('NO')
      end

      it 'converts nil values to N/A' do
        test_data = {
          'isProprietaryProfit' => nil,
          'isProfitConflictOfInterest' => nil,
          'allProprietaryConflictOfInterest' => nil
        }
        form_instance.send(:convert_boolean_fields, test_data)

        expect(test_data['isProprietaryProfit']).to eq('N/A')
        expect(test_data['isProfitConflictOfInterest']).to eq('N/A')
        expect(test_data['allProprietaryConflictOfInterest']).to eq('N/A')
      end
    end

    describe '#process_proprietary_conflicts' do
      it 'processes conflicts and combines names' do
        test_data = {
          'proprietaryProfitConflicts' => [
            {
              'affiliatedIndividuals' => {
                'first' => 'John',
                'last' => 'Doe',
                'individualAssociationType' => 'va'
              }
            },
            {
              'affiliatedIndividuals' => {
                'first' => 'Jane',
                'last' => 'Smith',
                'individualAssociationType' => 'saa'
              }
            }
          ]
        }
        form_instance.send(:process_proprietary_conflicts, test_data)

        expect(test_data['proprietaryProfitConflicts0']['employeeName']).to eq('John Doe')
        expect(test_data['proprietaryProfitConflicts0']['association']).to eq('VA')
        expect(test_data['proprietaryProfitConflicts1']['employeeName']).to eq('Jane Smith')
        expect(test_data['proprietaryProfitConflicts1']['association']).to eq('SAA')
      end

      it 'limits processing to first 2 conflicts' do
        test_data = {
          'proprietaryProfitConflicts' => [
            { 'affiliatedIndividuals' => { 'first' => 'One', 'last' => 'Person',
                                           'individualAssociationType' => 'va' } },
            { 'affiliatedIndividuals' => { 'first' => 'Two', 'last' => 'Person',
                                           'individualAssociationType' => 'saa' } },
            { 'affiliatedIndividuals' => { 'first' => 'Three', 'last' => 'Person',
                                           'individualAssociationType' => 'other' } }
          ]
        }
        form_instance.send(:process_proprietary_conflicts, test_data)

        expect(test_data['proprietaryProfitConflicts0']).to be_present
        expect(test_data['proprietaryProfitConflicts1']).to be_present
        expect(test_data['proprietaryProfitConflicts2']).to be_nil
      end

      it 'does nothing when proprietaryProfitConflicts is missing' do
        test_data = {}
        expect { form_instance.send(:process_proprietary_conflicts, test_data) }.not_to raise_error
        expect(test_data['proprietaryProfitConflicts0']).to be_nil
      end

      it 'handles nil individualAssociationType gracefully' do
        test_data = {
          'proprietaryProfitConflicts' => [
            {
              'affiliatedIndividuals' => {
                'first' => 'John',
                'last' => 'Doe',
                'individualAssociationType' => nil
              }
            }
          ]
        }
        form_instance.send(:process_proprietary_conflicts, test_data)

        expect(test_data['proprietaryProfitConflicts0']['association']).to be_nil
      end
    end

    describe '#process_all_proprietary_conflicts' do
      it 'processes all conflicts and combines official names' do
        test_data = {
          'allProprietaryProfitConflicts' => [
            {
              'certifyingOfficial' => {
                'first' => 'Alice',
                'last' => 'Johnson'
              },
              'fileNumber' => '123456789',
              'enrollmentPeriod' => {
                'from' => '2023-01-01',
                'to' => '2023-12-31'
              }
            }
          ]
        }
        form_instance.send(:process_all_proprietary_conflicts, test_data)

        expect(test_data['allProprietaryProfitConflicts0']['officialName']).to eq('Alice Johnson')
        expect(test_data['allProprietaryProfitConflicts0']['fileNumber']).to eq('123456789')
        expect(test_data['allProprietaryProfitConflicts0']['enrollmentDateRange']).to eq('2023-01-01')
        expect(test_data['allProprietaryProfitConflicts0']['enrollmentDateRangeEnd']).to eq('2023-12-31')
      end

      it 'limits processing to first 2 conflicts' do
        test_data = {
          'allProprietaryProfitConflicts' => [
            {
              'certifyingOfficial' => { 'first' => 'First', 'last' => 'Official' },
              'fileNumber' => '111111111',
              'enrollmentPeriod' => { 'from' => '2023-01-01', 'to' => '2023-12-31' }
            },
            {
              'certifyingOfficial' => { 'first' => 'Second', 'last' => 'Official' },
              'fileNumber' => '222222222',
              'enrollmentPeriod' => { 'from' => '2022-01-01', 'to' => '2022-12-31' }
            },
            {
              'certifyingOfficial' => { 'first' => 'Third', 'last' => 'Official' },
              'fileNumber' => '333333333',
              'enrollmentPeriod' => { 'from' => '2021-01-01', 'to' => '2021-12-31' }
            }
          ]
        }
        form_instance.send(:process_all_proprietary_conflicts, test_data)

        expect(test_data['allProprietaryProfitConflicts0']).to be_present
        expect(test_data['allProprietaryProfitConflicts1']).to be_present
        expect(test_data['allProprietaryProfitConflicts2']).to be_nil
      end

      it 'does nothing when allProprietaryProfitConflicts is missing' do
        test_data = {}
        expect { form_instance.send(:process_all_proprietary_conflicts, test_data) }.not_to raise_error
        expect(test_data['allProprietaryProfitConflicts0']).to be_nil
      end
    end

    describe '#convert_boolean_to_yes_no' do
      it 'converts true to YES' do
        result = form_instance.send(:convert_boolean_to_yes_no, true)
        expect(result).to eq('YES')
      end

      it 'converts false to NO' do
        result = form_instance.send(:convert_boolean_to_yes_no, false)
        expect(result).to eq('NO')
      end

      it 'converts nil to N/A' do
        result = form_instance.send(:convert_boolean_to_yes_no, nil)
        expect(result).to eq('N/A')
      end
    end
  end
end
