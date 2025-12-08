# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va221919'

RSpec.describe PdfFill::Forms::Formatters::Va221919 do
  describe '#process_certifying_official' do
    let(:form_data) do
      {
        'certifyingOfficial' => {
          'first' => 'John',
          'last' => 'Doe',
          'role' => {
            'level' => 'certifying official',
            'other' => nil
          }
        }
      }
    end

    it 'sets the full name' do
      described_class.process_certifying_official(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to eq('John Doe')
    end

    it 'uppercases the role' do
      described_class.process_certifying_official(form_data)
      expect(form_data['certifyingOfficial']['role']['displayRole']).to eq('CERTIFYING OFFICIAL')
    end

    context 'when role is other' do
      let(:form_data) do
        {
          'certifyingOfficial' => {
            'first' => 'John',
            'last' => 'Doe',
            'role' => {
              'level' => 'other',
              'other' => 'some other role'
            }
          }
        }
      end

      it 'uses the other role and uppercases it' do
        described_class.process_certifying_official(form_data)
        expect(form_data['certifyingOfficial']['role']['displayRole']).to eq('SOME OTHER ROLE')
      end
    end
  end

  describe '#process_institution_address' do
    let(:form_data) do
      {
        'institutionDetails' => {
          'institutionAddress' => {
            'street' => '123 Main St',
            'city' => 'Anytown',
            'state' => 'NY',
            'postalCode' => '12345'
          }
        }
      }
    end

    it 'formats the address with city, state, and zip' do
      described_class.process_institution_address(form_data)
      expect(form_data['institutionDetails']['institutionAddress']['street']).to eq('123 Main St Anytown, NY 12345')
    end
  end

  describe '#process_proprietary_conflicts' do
    let(:form_data) do
      {
        'proprietaryProfitConflicts' => [
          {
            'affiliatedIndividuals' => {
              'first' => 'Jane',
              'last' => 'Smith',
              'title' => 'Manager',
              'individualAssociationType' => 'va'
            }
          },
          {
            'affiliatedIndividuals' => {
              'first' => 'Bob',
              'last' => 'Jones',
              'title' => nil,
              'individualAssociationType' => 'saa'
            }
          }
        ]
      }
    end

    it 'formats employee names with titles' do
      described_class.process_proprietary_conflicts(form_data)
      expect(form_data['proprietaryProfitConflicts0']['employeeName']).to eq('Jane Smith, Manager')
      expect(form_data['proprietaryProfitConflicts1']['employeeName']).to eq('Bob Jones')
    end

    it 'updates association types to include "employee" for VA and SAA' do
      described_class.process_proprietary_conflicts(form_data)
      expect(form_data['proprietaryProfitConflicts0']['association']).to eq('VA EMPLOYEE')
      expect(form_data['proprietaryProfitConflicts1']['association']).to eq('SAA EMPLOYEE')
    end
  end

  describe '#process_all_proprietary_conflicts' do
    let(:form_data) do
      {
        'allProprietaryProfitConflicts' => [
          {
            'certifyingOfficial' => {
              'first' => 'Alice',
              'last' => 'Wonder',
              'title' => 'Director'
            },
            'fileNumber' => '12345',
            'enrollmentPeriod' => {
              'from' => '2023-01-01',
              'to' => '2023-12-31'
            }
          }
        ]
      }
    end

    it 'formats official names with titles' do
      described_class.process_all_proprietary_conflicts(form_data)
      expect(form_data['allProprietaryProfitConflicts0']['officialName']).to eq('Alice Wonder, Director')
    end

    it 'formats dates as MM/DD/YYYY' do
      described_class.process_all_proprietary_conflicts(form_data)
      expect(form_data['allProprietaryProfitConflicts0']['enrollmentDateRange']).to eq('01/01/2023')
      expect(form_data['allProprietaryProfitConflicts0']['enrollmentDateRangeEnd']).to eq('12/31/2023')
    end
  end
end
