# frozen_string_literal: true

require 'rails_helper'
require 'dmc/fsr_service'

RSpec.describe DMC::FSRService do
  describe '#submit_financial_status_report' do
    let(:valid_form_data) do
      {
        'personalIdentification' => {
          'fsrReason' => 'Compromise'
        },
        'personalData' => {
            'veteranFullName' => {
                'first' => 'Greg',
                'middle' => 'A',
                'last' => 'Anderson'
            },
            'address' => {
                'addresslineOne' => '123 Fake Street',
                'addresslineTwo' => 'Apt 120',
                'addresslineThree' => '',
                'city' => 'Fakerville',
                'stateOrProvince' => 'CO',
                'zipOrPostalCode' => '11111',
                'countryName' => 'USA'
            },
            'telephoneNumber' => '1-6099008787',
            'dateOfBirth' => '06/28/1957',
            'married' => true,
            'spouseFullName' => {
                'first' => 'Lisa',
                'middle' => 'A',
                'last' => 'Anderson'
            },
            'agesOfOtherDependents' => [
                '14',
                '6'
            ],
            'employmentHistory' => [
                {
                    'veteranOrSpouse' => 'VETERAN',
                    'occupationName' => 'welder',
                    'from' => '06/2019',
                    'to' => '',
                    'present' => true,
                    'employerName' => 'Faker Metal Fabrications Inc.',
                    'employerAddress' => {
                        'addresslineOne' => '321 Notreal Avenue',
                        'addresslineTwo' => '',
                        'addresslineThree' => '',
                        'city' => 'Fakerville',
                        'stateOrProvince' => 'CO',
                        'zipOrPostalCode' => '11111',
                        'countryName' => 'USA'
                    }
                },
                {
                    'veteranOrSpouse' => 'VETERAN',
                    'occupationName' => 'welder',
                    'from' => '06/2017',
                    'to' => '06/2019',
                    'present' => false,
                    'employerName' => 'Subway Metal Fabrications Inc.',
                    'employerAddress' => {
                        'addresslineOne' => '321 Knox Avenue',
                        'addresslineTwo' => '',
                        'addresslineThree' => '',
                        'city' => 'Fakerville',
                        'stateOrProvince' => 'CO',
                        'zipOrPostalCode' => '11111',
                        'countryName' => 'USA'
                    }
                },
                {
                    'veteranOrSpouse' => 'SPOUSE',
                    'occupationName' => 'welder',
                    'from' => '06/2017',
                    'to' => '',
                    'present' => true,
                    'employerName' => 'Faker Metal Fabrications Inc.',
                    'employerAddress' => {
                        'addresslineOne' => '321 Notreal Avenue',
                        'addresslineTwo' => '',
                        'addresslineThree' => '',
                        'city' => 'Fakerville',
                        'stateOrProvince' => 'CO',
                        'zipOrPostalCode' => '11111',
                        'countryName' => 'USA'
                    }
                }
            ]
        },
        'income' => [
        {
            'veteranOrSpouse' => 'VETERAN',
            'monthlyGrossSalary' => '450000',
            'deductions' => {
                'taxes' => '67500',
                'retirement' => '67500',
                'socialSecurity' => '67500',
                'otherDeductions' => {
                    'name' => 'health savings account',
                    'amount' => '67500'
                }
            },
            'totalDeductions' => '252500',
            'netTakeHomePay' => '197500',
            'otherIncome' => {
                'name' => 'VA Disability Compensation',
                'amount' => '150000'
            },
            'totalMonthlyNetIncome' => '347500'
        },
        {
            'veteranOrSpouse' => 'SPOUSE',
            'monthlyGrossSalary' => '450000',
            'deductions' => {
            'taxes' => '67500',
            'retirement' => '67500',
            'socialSecurity' => '67500',
            'otherDeductions' => {
                'name' => 'health savings account',
                'amount' => '67500'
            }
            },
            'totalDeductions' => '252500',
            'netTakeHomePay' => '197500',
            'otherIncome' => {
            'name' => 'VA Disability Compensation',
            'amount' => '150000'
            },
            'totalMonthlyNetIncome' => '347500'
        }
        ],
        'expenses' => {
            'rentOrMortgage' => '100000',
            'food' => '60000',
            'utilities' => '30000',
            'otherLivingExpenses' => {
                'name' => 'charity donations',
                'amount' => '150000'
            },
            'expensesInstallmentContractsAndOtherDebts' => '50000',
            'totalMonthlyExpenses' => '240000'
        },
        'discretionaryIncome' => {
            'netMonthlyIncomeLessExpenses' => '107500',
            'amountCanBePaidTowardDebt' => '107500'
        },
        'assets' => {
            'cashInBank' => '123 Letter NOT sent',
            'cashOnHand' => 'Project write-off',
            'automobiles' => [
                {
                'make' => 'Pontiac',
                'model' => 'Grand AM',
                'year' => '1999',
                'resaleValue' => '200000'
                }
            ],
            'trailersBoatsCampers' => '400',
            'usSavingsBonds' => '',
            'stocksAndOtherBonds' => '10000000',
            'realEstateOwned' => '25000000',
            'otherAssets' => [
                {
                'name' => 'gold',
                'amount' => '150000'
                }
            ],
            'totalAssets' => '39000000'
        },
        'installmentContractsAndOtherDebts' => [
            {
                'creditorName' => 'Faker Bank',
                'creditorAddress' => {
                    'addresslineOne' => '555 Bogus Street',
                    'addresslineTwo' => '',
                    'addresslineThree' => '',
                    'city' => 'Fakerville',
                    'stateORProvince' => 'CO',
                    'zipORPostalCode' => '11111',
                    'countryName' => 'USA'
                },
                'dateStarted' => '06/28/2020',
                'purpose' => 'debt consolidation loan',
                'originalAmount' => '1500000',
                'unpaidBalance' => '100000',
                'amountDueMonthly' => '50000',
                'amountPastDue' => '0'
            }
        ],
        'totalOfInstallmentContractsAndOtherDebts' => {
            'originalAmount' => '4500000',
            'unpaidBalance' => '300000',
            'amountDueMonthly' => '80000',
            'amountPastDue' => '0'
        },
        'additionalData' => {
            'bankruptcy' => {
                'hasBeenAdjudicatedBankrupt' => false,
                'dateDischarged' => '',
                'courtLocation' => '',
                'docketNumber' => ''
            },
            'additionalComments' => 'No comments'
        }
      }
    end

    let(:malformed_form_data) do
      { 'bad' => 'data' }
    end

    context 'with valid form data' do
      it 'accepts the submission' do
        VCR.use_cassette('dmc/submit_fsr') do
          service = described_class.new
          res = service.submit_financial_status_report(valid_form_data)
          expect(res.status).to eq('Document created successfully and uploaded to File Net.')
        end
      end
    end

    context 'with malformed form' do
      it 'does not accept the submission' do
        VCR.use_cassette('dmc/submit_fsr_error') do
          service = described_class.new
          expect { service.submit_financial_status_report(malformed_form_data) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) do |e|
            expect(e.message).to match(/DMC400/)
          end
        end
      end
    end
  end
end
