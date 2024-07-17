# frozen_string_literal: true

require 'rails_helper'
require 'decision_review/schemas'
require 'disability_compensation/factories/api_provider_factory'
require 'gi/client'

RSpec.describe FormProfile, type: :model do
  include SchemaMatchers

  let(:user) { build(:user, :loa3, suffix: 'Jr.', address: build(:mpi_profile_address)) }

  before do
    stub_evss_pciu(user)
    described_class.instance_variable_set(:@mappings, nil)
    Flipper.disable(:disability_526_toxic_exposure)
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
  end

  let(:street_check) { build(:street_check) }

  let(:form_profile) do
    described_class.new(form_id: 'foo', user:)
  end

  let(:us_phone) { form_profile.send :pciu_us_phone }

  let(:full_name) do
    {
      'first' => user.first_name&.capitalize,
      'middle' => user.middle_name&.capitalize,
      'last' => user.last_name&.capitalize,
      'suffix' => user.suffix
    }
  end

  let(:veteran_service_information) do
    {

      'branchOfService' => 'Army',
      'serviceDateRange' => {
        'from' => '2012-03-02',
        'to' => '2018-10-31'
      }
    }
  end

  let(:veteran_full_name) do
    {
      'veteranFullName' => full_name
    }
  end

  let(:address) do
    {
      'street' => street_check[:street],
      'street2' => street_check[:street2],
      'city' => user.address[:city],
      'state' => user.address[:state],
      'country' => user.address[:country],
      'postal_code' => user.address[:postal_code].slice(0, 5)
    }
  end

  let(:veteran_address) do
    {
      'veteranAddress' => address
    }
  end

  let(:tours_of_duty) do
    [
      {
        'service_branch' => 'Army',
        'date_range' => { 'from' => '1985-08-19', 'to' => '1989-08-19' }
      },
      {
        'service_branch' => 'Army',
        'date_range' => { 'from' => '1989-08-20', 'to' => '1992-08-23' }
      },
      {
        'service_branch' => 'Army',
        'date_range' => { 'from' => '1989-08-20', 'to' => '2002-07-01' }
      },
      {
        'service_branch' => 'Air Force',
        'date_range' => { 'from' => '2000-04-07', 'to' => '2009-01-23' }
      },
      {
        'service_branch' => 'Army',
        'date_range' => { 'from' => '2002-07-02', 'to' => '2014-08-31' }
      }
    ]
  end

  let(:v40_10007_expected) do
    {
      'application' => {
        'claimant' => {
          'address' => address,
          'dateOfBirth' => user.birth_date,
          'name' => full_name,
          'ssn' => FormIdentityInformation.new(ssn: user.ssn).hyphenated_ssn,
          'email' => user.pciu_email,
          'phoneNumber' => us_phone
        }
      }
    }
  end

  let(:v0873_expected) do
    {
      'personalInformation' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix,
        'preferredName' => 'SAM',
        'dateOfBirth' => user.birth_date,
        'socialSecurityNumber' => user.ssn,
        'serviceNumber' => '123455678'
      },
      'contactInformation' => {
        'email' => user.pciu_email,
        'phone' => us_phone,
        'address' => address
      },
      'avaProfile' => {
        'schoolInfo' => {
          'schoolFacilityCode' => '12345678',
          'schoolName' => 'Fake School'
        },
        'businessPhone' => '1234567890',
        'businessEmail' => 'fake@company.com'
      },
      'veteranServiceInformation' => veteran_service_information
    }
  end

  let(:v686_c_674_expected) do
    {
      'veteranContactInformation' => {
        'veteranAddress' => {
          'addressLine1' => '140 Rock Creek Rd',
          'countryName' => 'USA',
          'city' => 'Washington',
          'stateCode' => 'DC',
          'zipCode' => '20011'
        },
        'phoneNumber' => '4445551212',
        'emailAddress' => 'test2@test1.net'
      },
      'veteranInformation' => {
        'fullName' => {
          'first' => user.first_name.capitalize,
          'last' => user.last_name.capitalize,
          'suffix' => 'Jr.'
        },
        'ssn' => '796111863',
        'birthDate' => '1809-02-12'
      }
    }
  end

  let(:v21_686_c_expected) do
    {
      'veteranFullName' => {
        'first' => 'WESLEY',
        'middle' => 'Watson',
        'last' => 'FORD'
      },
      'veteranAddress' => {
        'addressType' => 'DOMESTIC',
        'street' => '3001 PARK CENTER DR',
        'street2' => 'APT 212',
        'city' => 'ALEXANDRIA',
        'state' => 'VA',
        'countryDropdown' => 'USA',
        'postalCode' => '22302'
      },
      'veteranEmail' => 'evssvsotest@gmail.com',
      'veteranSocialSecurityNumber' => '796043735',
      'dayPhone' => '2024619724',
      'maritalStatus' => 'NEVERMARRIED',
      'nightPhone' => '7893256545',
      'spouseMarriages' => [
        {
          'dateOfMarriage' => '1979-02-01',
          'locationOfMarriage' => {
            'countryDropdown' => 'USA',
            'city' => 'Washington',
            'state' => 'DC'
          },
          'spouseFullName' => {
            'first' => 'Dennis',
            'last' => 'Menise'
          }
        }
      ],
      'marriages' => [
        {
          'dateOfMarriage' => '1979-02-01',
          'locationOfMarriage' => {
            'countryDropdown' => 'USA',
            'city' => 'Washington',
            'state' => 'DC'
          },
          'spouseFullName' => {
            'first' => 'Dennis',
            'last' => 'Menise'
          }
        },
        {
          'dateOfMarriage' => '2018-02-02',
          'locationOfMarriage' => {
            'countryDropdown' => 'USA',
            'city' => 'Washington',
            'state' => 'DC'
          },
          'spouseFullName' => {
            'first' => 'Martha',
            'last' => 'Stewart'
          }
        }
      ],
      'currentMarriage' => {
        'spouseSocialSecurityNumber' => '579009999',
        'liveWithSpouse' => true,
        'spouseDateOfBirth' => '1969-02-16'
      },
      'dependents' => [
        {
          'fullName' => {
            'first' => 'ONE',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2018-08-02',
          'childInHousehold' => true,
          'childHasNoSsn' => true,
          'childHasNoSsnReason' => 'NOSSNASSIGNEDBYSSA'
        },
        {
          'fullName' => {
            'first' => 'TWO',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2018-08-02',
          'childInHousehold' => true,
          'childSocialSecurityNumber' => '092120182'
        },
        {
          'fullName' => {
            'first' => 'THREE',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2017-08-02',
          'childInHousehold' => true,
          'childSocialSecurityNumber' => '092120183'
        },
        {
          'fullName' => {
            'first' => 'FOUR',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2017-08-02',
          'childInHousehold' => true,
          'childSocialSecurityNumber' => '092120184'
        },
        {
          'fullName' => {
            'first' => 'FIVE',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2016-08-02',
          'childInHousehold' => true,
          'childSocialSecurityNumber' => '092120185'
        },
        {
          'fullName' => {
            'first' => 'SIX',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2015-08-02',
          'childInHousehold' => true,
          'childSocialSecurityNumber' => '092120186'
        },
        {
          'fullName' => {
            'first' => 'TEST',
            'last' => 'FORD'
          },
          'childDateOfBirth' => '2018-08-07',
          'childInHousehold' => true,
          'childSocialSecurityNumber' => '221223524'
        }
      ]
    }
  end

  let(:v22_1990_expected) do
    {
      'toursOfDuty' => tours_of_duty,
      'currentlyActiveDuty' => {
        'yes' => false
      },
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'gender' => user.gender,
      'homePhone' => us_phone,
      'veteranDateOfBirth' => user.birth_date,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_0993_expected) do
    {
      'claimantFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'claimantSocialSecurityNumber' => user.ssn
    }
  end

  let(:v22_0994_expected) do
    {
      'activeDuty' => false,
      'mailingAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'applicantFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'applicantGender' => user.gender,
      'dayTimePhone' => us_phone,
      'dateOfBirth' => user.birth_date,
      'applicantSocialSecurityNumber' => user.ssn,
      'emailAddress' => user.pciu_email
    }
  end

  let(:v22_1990_n_expected) do
    {
      'toursOfDuty' => tours_of_duty,
      'currentlyActiveDuty' => {
        'yes' => false
      },
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'gender' => user.gender,
      'homePhone' => us_phone,
      'veteranDateOfBirth' => user.birth_date,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_1990_e_expected) do
    {
      'relativeAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'relativeFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'relativeSocialSecurityNumber' => user.ssn
    }
  end

  let(:v22_1995_expected) do
    {
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_1995_s_expected) do
    {
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_10203_expected) do
    {
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.pciu_email
    }
  end

  let(:v22_5490_expected) do
    {
      'toursOfDuty' => tours_of_duty,
      'currentlyActiveDuty' => false,
      'relativeFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'relativeSocialSecurityNumber' => user.ssn,
      'relativeDateOfBirth' => user.birth_date
    }
  end

  let(:v22_5495_expected) do
    {
      'toursOfDuty' => tours_of_duty,
      'currentlyActiveDuty' => false,
      'relativeFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'relativeSocialSecurityNumber' => user.ssn,
      'relativeDateOfBirth' => user.birth_date
    }
  end

  let(:v1010ez_expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'veteranDateOfBirth' => user.birth_date,
      'email' => user.pciu_email,
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'swAsiaCombat' => false,
      'lastServiceBranch' => 'army',
      'lastEntryDate' => '2002-07-02',
      'lastDischargeDate' => '2014-08-31',
      'gender' => user.gender,
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn
    }
  end

  let(:vmdot_expected) do
    {
      'fullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'permanentAddress' => {
        'street' => '456 ANYPLACE RD',
        'city' => 'PENSACOLA',
        'state' => 'FL',
        'country' => 'United States',
        'postalCode' => '33344'
      },
      'temporaryAddress' => {
        'street' => '123 SOMEWHERE',
        'street2' => 'OUT THERE',
        'city' => 'DENVER',
        'state' => 'CO',
        'country' => 'United States',
        'postalCode' => '80030'
      },
      'ssnLastFour' => user.ssn.last(4),
      'gender' => user.gender,
      'vetEmail' => 'veteran@gmail.com',
      'dateOfBirth' => user.birth_date,
      'eligibility' => {
        'accessories' => true,
        'apneas' => true,
        'batteries' => true
      },
      'supplies' => [
        {
          'productName' => 'ERHK HE11 680 MINI',
          'productGroup' => 'ACCESSORIES',
          'productId' => 6584,
          'availableForReorder' => true,
          'lastOrderDate' => '2019-11-22',
          'nextAvailabilityDate' => '2020-04-22',
          'quantity' => 1
        },
        {
          'productName' => 'ZA10',
          'productGroup' => 'BATTERIES',
          'productId' => 3315,
          'availableForReorder' => true,
          'lastOrderDate' => '2019-12-01',
          'nextAvailabilityDate' => '2020-05-01',
          'quantity' => 24
        },
        {
          'deviceName' => 'WILLIAMS SOUND CORP./POCKETALKER II',
          'productName' => 'M312',
          'productGroup' => 'BATTERIES',
          'productId' => 2298,
          'availableForReorder' => false,
          'lastOrderDate' => '2020-05-06',
          'nextAvailabilityDate' => '2020-10-06',
          'quantity' => 12
        },
        {
          'deviceName' => 'SIVANTOS/SIEMENS/007ASP2',
          'productName' => 'ZA13',
          'productGroup' => 'BATTERIES',
          'productId' => 2314,
          'availableForReorder' => false,
          'lastOrderDate' => '2020-05-06',
          'nextAvailabilityDate' => '2020-10-06',
          'quantity' => 60
        },
        {
          'deviceName' => '',
          'productName' => 'AIRFIT P10',
          'productGroup' => 'Apnea',
          'productId' => 6650,
          'availableForReorder' => true,
          'lastOrderDate' => '2022-07-05',
          'nextAvailabilityDate' => '2022-12-05',
          'quantity' => 1
        },
        {
          'deviceName' => '',
          'productName' => 'AIRCURVE10-ASV-CLIMATELINE',
          'productGroup' => 'Apnea',
          'productId' => 8467,
          'availableForReorder' => false,
          'lastOrderDate' => '2022-07-06',
          'nextAvailabilityDate' => '2022-12-06',
          'quantity' => 1
        }
      ]
    }
  end

  let(:v5655_expected) do
    {
      'personalIdentification' => {
        'ssn' => user.ssn.last(4),
        'fileNumber' => '3735'
      },
      'personalData' => {
        'veteranFullName' => full_name,
        'address' => address,
        'telephoneNumber' => us_phone,
        'emailAddress' => user.pciu_email,
        'dateOfBirth' => user.birth_date
      },
      'income' => [
        {
          'veteranOrSpouse' => 'VETERAN',
          'compensationAndPension' => '3000'
        }
      ]
    }
  end

  let(:vvic_expected) do
    {
      'email' => user.pciu_email,
      'serviceBranches' => ['F'],
      'gender' => user.gender,
      'verified' => true,
      'veteranDateOfBirth' => user.birth_date,
      'phone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn
    }.merge(veteran_full_name).merge(veteran_address)
  end

  let(:v21_p_527_ez_expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'veteranSocialSecurityNumber' => user.ssn,
      'veteranDateOfBirth' => user.birth_date
    }
  end

  let(:v21_p_530_expected) do
    {
      'claimantFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'claimantAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => 'US',
        'postal_code' => user.address[:postal_code][0..4]
      },
      'claimantPhone' => us_phone,
      'claimantEmail' => user.pciu_email
    }
  end

  let(:v21_526_ez_expected) do
    {
      'disabilities' => [
        {
          'diagnosticCode' => 5238,
          'decisionCode' => 'SVCCONNCTED',
          'decisionText' => 'Service Connected',
          'name' => 'Diabetes mellitus0',
          'ratedDisabilityId' => '1',
          'ratingDecisionId' => '63655',
          'ratingPercentage' => 100
        },
        {
          'diagnosticCode' => 5238,
          'decisionCode' => 'SVCCONNCTED',
          'decisionText' => 'Service Connected',
          'name' => 'Diabetes mellitus1',
          'ratedDisabilityId' => '2',
          'ratingDecisionId' => '63655',
          'ratingPercentage' => 100
        }
      ],
      'servicePeriods' => [
        {
          'serviceBranch' => 'Army',
          'dateRange' => { 'from' => '2002-07-02', 'to' => '2014-08-31' }
        },
        {
          'serviceBranch' => 'Air National Guard',
          'dateRange' => { 'from' => '2000-04-07', 'to' => '2009-01-23' }
        },
        {
          'serviceBranch' => 'Army Reserve',
          'dateRange' => { 'from' => '1989-08-20', 'to' => '2002-07-01' }
        },
        {
          'serviceBranch' => 'Army Reserve',
          'dateRange' => { 'from' => '1989-08-20', 'to' => '1992-08-23' }
        },
        {
          'serviceBranch' => 'Army',
          'dateRange' => { 'from' => '1985-08-19', 'to' => '1989-08-19' }
        }
      ],
      'reservesNationalGuardService' => {
        'obligationTermOfServiceDateRange' => {
          'from' => '2000-04-07',
          'to' => '2009-01-23'
        }
      },
      'veteran' => {
        'mailingAddress' => {
          'country' => 'USA',
          'city' => 'Washington',
          'state' => 'DC',
          'zipCode' => '20011',
          'addressLine1' => '140 Rock Creek Rd'
        },
        'primaryPhone' => '4445551212',
        'emailAddress' => 'test2@test1.net'
      },
      'bankAccountNumber' => '*********1234',
      'bankAccountType' => 'Checking',
      'bankName' => 'Comerica',
      'bankRoutingNumber' => '*****2115',
      'startedFormVersion' => '2022'
    }
  end

  let(:vfeedback_tool_expected) do
    {
      'address' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => 'US',
        'postal_code' => user.address[:postal_code][0..4]
      },
      'serviceBranch' => 'Army',
      'fullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'applicantEmail' => user.pciu_email,
      'phone' => us_phone,
      'serviceDateRange' => {
        'from' => '2002-07-02',
        'to' => '2014-08-31'
      }
    }
  end

  let(:v26_1880_expected) do
    {
      'fullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'dateOfBirth' => '1809-02-12',
      'applicantAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'contactPhone' => us_phone,
      'contactEmail' => user.pciu_email,
      'periodsOfService' => tours_of_duty,
      'currentlyActiveDuty' => {
        'yes' => false
      },
      'activeDuty' => false
    }
  end

  let(:v28_8832_expected) do
    {
      'claimantAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'claimantPhoneNumber' => us_phone,
      'claimantEmailAddress' => user.pciu_email
    }
  end

  let(:v28_1900_expected) do
    {
      'veteranInformation' => {
        'fullName' => {
          'first' => user.first_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'ssn' => '796111863',
        'dob' => '1809-02-12'
      },
      'veteranAddress' => {
        'street' => street_check[:street],
        'street2' => street_check[:street2],
        'city' => user.address[:city],
        'state' => user.address[:state],
        'country' => user.address[:country],
        'postal_code' => user.address[:postal_code][0..4]
      },
      'mainPhone' => us_phone,
      'email' => user.pciu_email
    }
  end

  let(:v26_4555_expected) do
    {
      'veteran' => {
        'fullName' => {
          'first' => user.first_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'ssn' => '796111863',
        'dateOfBirth' => '1809-02-12',
        'homePhone' => '14445551212',
        'email' => user.pciu_email,
        'address' => {
          'street' => street_check[:street],
          'street2' => street_check[:street2],
          'city' => user.address[:city],
          'state' => user.address[:state],
          'country' => user.address[:country],
          'postal_code' => user.address[:postal_code][0..4]
        }
      }
    }
  end

  let(:v21_0966_expected) do
    {
      'veteran' => {
        'fullName' => {
          'first' => user.first_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'ssn' => '796111863',
        'dateOfBirth' => '1809-02-12',
        'homePhone' => '14445551212',
        'email' => user.pciu_email,
        'address' => {
          'street' => street_check[:street],
          'street2' => street_check[:street2],
          'city' => user.address[:city],
          'state' => user.address[:state],
          'country' => user.address[:country],
          'postal_code' => user.address[:postal_code][0..4]
        }
      }
    }
  end

  let(:initialize_va_profile_prefill_military_information_expected) do
    expected_service_episodes_by_date = [
      {
        begin_date: '2012-03-02',
        branch_of_service: 'Army',
        branch_of_service_code: 'A',
        character_of_discharge_code: nil,
        deployments: [],
        end_date: '2018-10-31',
        period_of_service_type_code: 'N',
        period_of_service_type_text: 'National Guard member',
        service_type: 'Military Service',
        termination_reason_code: 'C',
        termination_reason_text: 'Completion of Active Service period'
      },
      {
        begin_date: '2009-03-01',
        branch_of_service: 'Navy',
        branch_of_service_code: 'N',
        character_of_discharge_code: nil,
        deployments: [],
        end_date: '2012-12-31',
        period_of_service_type_code: 'N',
        period_of_service_type_text: 'National Guard member',
        service_type: 'Military Service',
        termination_reason_code: 'C',
        termination_reason_text: 'Completion of Active Service period'
      },
      {
        begin_date: '2002-02-02',
        branch_of_service: 'Army',
        branch_of_service_code: 'A',
        character_of_discharge_code: nil,
        deployments: [],
        end_date: '2008-12-01',
        period_of_service_type_code: 'N',
        period_of_service_type_text: 'National Guard member',
        service_type: 'Military Service',
        termination_reason_code: 'C',
        termination_reason_text: 'Completion of Active Service period'
      }
    ]

    {
      'currently_active_duty' => false,
      'currently_active_duty_hash' => {
        yes: false
      },
      'discharge_type' => nil,
      'guard_reserve_service_history' => [
        {
          from: '2012-03-02',
          to: '2018-10-31'
        },
        {
          from: '2009-03-01',
          to: '2012-12-31'
        },
        {
          from: '2002-02-02',
          to: '2008-12-01'
        }
      ],
      'hca_last_service_branch' => 'army',
      'last_discharge_date' => '2018-10-31',
      'last_entry_date' => '2012-03-02',
      'last_service_branch' => 'Army',
      'latest_guard_reserve_service_period' => {
        from: '2012-03-02',
        to: '2018-10-31'
      },
      'post_nov111998_combat' => false,
      'service_branches' => %w[A N],
      'service_episodes_by_date' => expected_service_episodes_by_date,
      'service_periods' => [
        { service_branch: 'Army National Guard', date_range: { from: '2012-03-02', to: '2018-10-31' } },
        { service_branch: 'Army National Guard', date_range: { from: '2002-02-02', to: '2008-12-01' } }
      ],
      'sw_asia_combat' => false,
      'tours_of_duty' => [
        { service_branch: 'Army', date_range: { from: '2002-02-02', to: '2008-12-01' } },
        { service_branch: 'Navy', date_range: { from: '2009-03-01', to: '2012-12-31' } },
        { service_branch: 'Army', date_range: { from: '2012-03-02', to: '2018-10-31' } }
      ]
    }
  end

  describe '#initialize_military_information', :skip_va_profile do
    context 'with military_information vaprofile' do
      it 'prefills military data from va profile' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
          output = form_profile.send(:initialize_military_information).attributes.transform_keys(&:to_s)

          expected_output = initialize_va_profile_prefill_military_information_expected
          expected_output['vic_verified'] = false

          actual_service_histories = output.delete('service_episodes_by_date')
          actual_guard_reserve_service_history = output.delete('guard_reserve_service_history')
          actual_latest_guard_reserve_service_period = output.delete('latest_guard_reserve_service_period')

          expected_service_histories = expected_output.delete('service_episodes_by_date')
          expected_guard_reserve_service_history = expected_output.delete('guard_reserve_service_history')
          expected_latest_guard_reserve_service_period = expected_output.delete('latest_guard_reserve_service_period')

          # Now that the nested structures are removed from the outputs, compare the rest of the structure.
          expect(output).to eq(expected_output)
          # Compare the nested structures VAProfile::Models::ServiceHistory objects separately.
          expect(actual_service_histories.map(&:attributes)).to eq(expected_service_histories)

          first_item = actual_guard_reserve_service_history.map(&:attributes).first
          expect(first_item[:from].to_s).to eq(expected_guard_reserve_service_history.first[:from])
          expect(first_item[:to].to_s).to eq(expected_guard_reserve_service_history.first[:to])

          guard_period = actual_latest_guard_reserve_service_period.attributes.transform_keys(&:to_s)
          expect(guard_period['from'].to_s).to eq(expected_latest_guard_reserve_service_period[:from])
          expect(guard_period['to'].to_s).to eq(expected_latest_guard_reserve_service_period[:to])
        end
      end
    end
  end

  describe '#initialize_va_profile_prefill_military_information' do
    context 'when va profile is down in production' do
      it 'logs exception and returns empty hash' do
        expect(form_profile).to receive(:log_exception_to_sentry).with(
          instance_of(VCR::Errors::UnhandledHTTPRequestError), {}, prefill: :va_profile_prefill_military_information
        )
        expect(form_profile.send(:initialize_va_profile_prefill_military_information)).to eq({})
      end
    end

    it 'prefills military data from va profile' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                       allow_playback_repeats: true, match_requests_on: %i[method body]) do
        output = form_profile.send(:initialize_va_profile_prefill_military_information)
        # Extract service_episodes_by_date and then compare their attributes
        actual_service_histories = output.delete('service_episodes_by_date')
        expected_service_histories = initialize_va_profile_prefill_military_information_expected
                                     .delete('service_episodes_by_date')

        # Now that service_episodes_by_date is removed from output and from
        # initialize_va_profile_prefill_military_information_expected, compare the rest of the structure.
        expect(output).to eq(initialize_va_profile_prefill_military_information_expected)

        # Compare service_episodes_by_date separately.
        # Convert each VAProfile::Models::ServiceHistory object to a hash of attributes so it can be
        # compared to the expected output.
        expect(actual_service_histories.map(&:attributes)).to eq(expected_service_histories)
      end
    end
  end

  describe '#pciu_us_phone' do
    def self.test_pciu_us_phone(primary, expected)
      it "returns #{expected}" do
        allow_any_instance_of(FormProfile).to receive(:pciu_primary_phone).and_return(primary)
        expect(form_profile.send(:pciu_us_phone)).to eq(expected)
      end
    end

    context 'with nil' do
      test_pciu_us_phone(nil, '')
    end

    context 'with an intl phone number' do
      test_pciu_us_phone('442079460976', '')
    end

    context 'with a us phone number' do
      test_pciu_us_phone('5557940976', '5557940976')
    end

    context 'with a us 1+ phone number' do
      test_pciu_us_phone('15557940976', '5557940976')
    end
  end

  describe '#extract_pciu_data' do
    it 'rescues EVSS::ErrorMiddleware::EVSSError errors' do
      expect(user).to receive(:pciu_primary_phone).and_raise(EVSS::ErrorMiddleware::EVSSError)

      expect(form_profile.send(:extract_pciu_data, :pciu_primary_phone)).to eq('')
    end
  end

  describe '#prefill_form' do
    def can_prefill_vaprofile(yes)
      expect(user).to receive(:authorize).at_least(:once).with(:va_profile, :access?).and_return(yes)
    end

    def strip_required(schema)
      new_schema = {}

      schema.each do |k, v|
        next if k == 'required'

        new_schema[k] = v.is_a?(Hash) ? strip_required(v) : v
      end

      new_schema
    end

    def expect_prefilled(form_id)
      prefilled_data = Oj.load(described_class.for(form_id:, user:).prefill.to_json)['form_data']

      case form_id
      when '1010ez'
        '10-10EZ'
      when '21-526EZ'
        '21-526EZ-ALLCLAIMS'
      else
        form_id
      end.tap do |schema_form_id|
        schema = strip_required(VetsJsonSchema::SCHEMAS[schema_form_id]).except('anyOf')
        schema_data = prefilled_data.deep_dup
        errors = JSON::Validator.fully_validate(
          schema,
          schema_data.deep_transform_keys { |key| key.camelize(:lower) }, validate_schema: true
        )

        expect(errors.empty?).to eq(true), "schema errors: #{errors}"
      end

      expect(prefilled_data).to eq(
        form_profile.send(:clean!, public_send("v#{form_id.underscore}_expected"))
      )
    end

    context 'with a user that can prefill 10-10EZR' do
      let(:form_profile) do
        FormProfiles::VA1010ezr.new(user:, form_id: 'f')
      end

      context 'when the ee service is down' do
        let(:v10_10_ezr_expected) do
          {
            'veteranFullName' => {
              'first' => user.first_name&.capitalize,
              'middle' => user.middle_name&.capitalize,
              'last' => user.last_name&.capitalize,
              'suffix' => user.suffix
            },
            'veteranSocialSecurityNumber' => user.ssn,
            'gender' => user.gender,
            'veteranDateOfBirth' => user.birth_date,
            'homePhone' => us_phone,
            'veteranAddress' => {
              'street' => street_check[:street],
              'street2' => street_check[:street2],
              'city' => user.address[:city],
              'state' => user.address[:state],
              'country' => user.address[:country],
              'postal_code' => user.address[:postal_code][0..4]
            },
            'email' => user.pciu_email
          }
        end

        it 'prefills the rest of the data and logs exception to sentry' do
          expect_any_instance_of(FormProfiles::VA1010ezr).to receive(:log_exception_to_sentry).with(
            instance_of(VCR::Errors::UnhandledHTTPRequestError)
          )
          expect_prefilled('10-10EZR')
        end
      end

      context 'with a user with dependents', run_at: 'Tue, 31 Oct 2023 12:04:33 GMT' do
        let(:v10_10_ezr_expected) do
          {
            'veteranFullName' => {
              'first' => user.first_name&.capitalize,
              'middle' => user.middle_name&.capitalize,
              'last' => user.last_name&.capitalize,
              'suffix' => user.suffix
            },
            'veteranSocialSecurityNumber' => user.ssn,
            'gender' => user.gender,
            'veteranDateOfBirth' => user.birth_date,
            'homePhone' => us_phone,
            'veteranAddress' => {
              'street' => street_check[:street],
              'street2' => street_check[:street2],
              'city' => user.address[:city],
              'state' => user.address[:state],
              'country' => user.address[:country],
              'postal_code' => user.address[:postal_code][0..4]
            },
            'email' => user.pciu_email,
            'spouseSocialSecurityNumber' => '435345344',
            'spouseDateOfBirth' => '1950-02-17',
            'dateOfMarriage' => '2000-10-15',
            'cohabitedLastYear' => true,
            'maritalStatus' => 'Married',
            'isMedicaidEligible' => false,
            'isEnrolledMedicarePartA' => false,
            'spouseFullName' => {
              'first' => 'VSDV',
              'last' => 'SDVSDV'
            }
          }
        end

        before do
          allow(user).to receive(:icn).and_return('1012829228V424035')
        end

        it 'returns a prefilled 10-10EZR form' do
          VCR.use_cassette(
            'hca/ee/dependents',
            VCR::MATCH_EVERYTHING.merge(erb: true)
          ) do
            expect_prefilled('10-10EZR')
          end
        end
      end

      context 'with a user with insurance data', run_at: 'Tue, 24 Oct 2023 17:27:12 GMT' do
        let(:v10_10_ezr_expected) do
          {
            'veteranFullName' => {
              'first' => user.first_name&.capitalize,
              'middle' => user.middle_name&.capitalize,
              'last' => user.last_name&.capitalize,
              'suffix' => user.suffix
            },
            'veteranSocialSecurityNumber' => user.ssn,
            'gender' => user.gender,
            'veteranDateOfBirth' => user.birth_date,
            'homePhone' => us_phone,
            'veteranAddress' => {
              'street' => street_check[:street],
              'street2' => street_check[:street2],
              'city' => user.address[:city],
              'state' => user.address[:state],
              'country' => user.address[:country],
              'postal_code' => user.address[:postal_code][0..4]
            },
            'email' => user.pciu_email,
            'maritalStatus' => 'Married',
            'isMedicaidEligible' => true,
            'isEnrolledMedicarePartA' => true,
            'medicarePartAEffectiveDate' => '1999-10-16',
            'medicareClaimNumber' => '873462432'
          }
        end

        before do
          allow(user).to receive(:icn).and_return('1013032368V065534')
        end

        it 'returns a prefilled 10-10EZR form' do
          VCR.use_cassette(
            'hca/ee/lookup_user_2023',
            VCR::MATCH_EVERYTHING.merge(erb: true)
          ) do
            expect_prefilled('10-10EZR')
          end
        end
      end
    end

    context 'with a user that can prefill mdot' do
      before do
        expect(user).to receive(:authorize).with(:mdot, :access?).and_return(true).at_least(:once)
        expect(user).to receive(:authorize).with(:va_profile, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:mdot, :access?)).to eq(true)
      end

      it 'returns a prefilled MDOT form', :skip_va_profile do
        VCR.use_cassette('mdot/get_supplies_200') do
          expect_prefilled('MDOT')
        end
      end
    end

    context 'with a user that can prefill financial status report' do
      let(:comp_and_pen_payments) do
        [
          { payment_date: DateTime.now - 2.months, payment_amount: '1500' },
          { payment_date: DateTime.now - 10.days, payment_amount: '3000' }
        ]
      end

      before do
        allow_any_instance_of(BGS::People::Service).to(
          receive(:find_person_by_participant_id).and_return(BGS::People::Response.new({ file_nbr: '796043735' }))
        )
        allow_any_instance_of(User).to(
          receive(:participant_id).and_return('600061742')
        )
        allow_any_instance_of(DebtManagementCenter::PaymentsService).to(
          receive(:compensation_and_pension).and_return(comp_and_pen_payments)
        )
        allow_any_instance_of(DebtManagementCenter::PaymentsService).to(
          receive(:education).and_return(nil)
        )
        allow(user).to receive(:authorize).and_return(true)
      end

      it 'returns a prefilled 5655 form' do
        expect_prefilled('5655')
      end

      context 'payment window' do
        let(:education_payments) do
          [
            { payment_date: DateTime.now - 3.months, payment_amount: '1500' }
          ]
        end

        before do
          allow_any_instance_of(DebtManagementCenter::PaymentsService).to(
            receive(:education).and_return(education_payments)
          )
        end

        it 'filters older payments when window is present' do
          allow(Settings.dmc).to receive(:fsr_payment_window).and_return(30)
          expect_prefilled('5655')
        end

        context 'no window present' do
          let(:v5655_expected) do
            {
              'personalIdentification' => {
                'ssn' => user.ssn.last(4),
                'fileNumber' => '3735'
              },
              'personalData' => {
                'veteranFullName' => full_name,
                'address' => address,
                'telephoneNumber' => us_phone,
                'emailAddress' => user.pciu_email,
                'dateOfBirth' => user.birth_date
              },
              'income' => [
                {
                  'veteranOrSpouse' => 'VETERAN',
                  'compensationAndPension' => '3000',
                  'education' => '1500'
                }
              ]
            }
          end

          it 'includes older payments when no window is present' do
            allow(Settings.dmc).to receive(:fsr_payment_window).and_return(nil)

            expect_prefilled('5655')
          end
        end
      end
    end

    context 'when VA Profile returns 404', :skip_va_profile do
      it 'returns default values' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_404',
                         allow_playback_repeats: true, match_requests_on: %i[method body]) do
          can_prefill_vaprofile(true)
          output = form_profile.send(:initialize_military_information).attributes.transform_keys(&:to_s)
          expect(output['currently_active_duty']).to eq(false)
          expect(output['currently_active_duty_hash']).to eq({ yes: false })
          expect(output['discharge_type']).to eq(nil)
          expect(output['guard_reserve_service_history']).to eq([])
          expect(output['hca_last_service_branch']).to eq('other')
          expect(output['last_discharge_date']).to eq(nil)
          expect(output['last_entry_date']).to eq(nil)
          expect(output['last_service_branch']).to eq(nil)
          expect(output['latest_guard_reserve_service_period']).to eq(nil)
          expect(output['post_nov111998_combat']).to eq(false)
          expect(output['service_branches']).to eq([])
          expect(output['service_episodes_by_date']).to eq([])
          expect(output['service_periods']).to eq([])
          expect(output['sw_asia_combat']).to eq(false)
          expect(output['tours_of_duty']).to eq([])
        end
      end
    end

    context 'when VA Profile returns 500', :skip_va_profile do
      it 'sends a BackendServiceException to Sentry and returns and empty hash' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500',
                         allow_playback_repeats: true, match_requests_on: %i[method uri]) do
          expect(form_profile).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Exceptions::BackendServiceException),
            {}, prefill: :va_profile_prefill_military_information
          )
          expect(form_profile.send(:initialize_va_profile_prefill_military_information)).to eq({})
        end
      end
    end

    context 'user without an address' do
      it 'prefills properly' do
        expect(user).to receive(:address).exactly(6).times.and_return(
          street: nil,
          street2: nil,
          city: nil,
          state: nil,
          country: nil,
          postal_code: nil
        )
        described_class.for(form_id: '22-1990e', user:).prefill
      end
    end

    context 'with military information data', :skip_va_profile do
      context 'with va profile prefill on' do
        before do
          VAProfile::Configuration::SETTINGS.prefill = true

          v22_1990_expected['email'] = VAProfileRedis::ContactInformation.for_user(user).email.email_address
          v22_1990_expected['homePhone'] = '3035551234'
          v22_1990_expected['mobilePhone'] = '3035551234'
          v22_1990_expected['veteranAddress'] = {
            'street' => '140 Rock Creek Rd',
            'city' => 'Washington',
            'state' => 'DC',
            'country' => 'USA',
            'postalCode' => '20011'
          }
        end

        after do
          VAProfile::Configuration::SETTINGS.prefill = false
        end

        it 'prefills 1990' do
          VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                           allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
            expect_prefilled('22-1990')
          end
        end
      end

      context 'with VA Profile prefill for 0994' do
        before do
          expect(user).to receive(:authorize).with(:ppiu, :access?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:va_profile, :access?).and_return(true).at_least(:once)
        end

        it 'prefills 0994' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                           allow_playback_repeats: true) do
            expect_prefilled('22-0994')
          end
        end
      end

      context 'with VA Profile and ppiu prefill for 0994' do
        before do
          can_prefill_vaprofile(true)
          expect(user).to receive(:authorize).with(:ppiu, :access?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
          v22_0994_expected['bankAccount'] = {
            'bankAccountNumber' => '*********1234',
            'bankAccountType' => 'Checking',
            'bankName' => 'Comerica',
            'bankRoutingNumber' => '*****2115'
          }
        end

        it 'prefills 0994 with VA Profile and payment information' do
          VCR.use_cassette('evss/pciu_address/address_domestic') do
            VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
              VCR.use_cassette('evss/ppiu/payment_information') do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  expect_prefilled('22-0994')
                end
              end
            end
          end
        end
      end

      context 'with VA Profile prefill for 0873' do
        let(:info) do
          {
            SchoolFacilityCode: '12345678',
            BusinessPhone: '1234567890',
            BusinessEmail: 'fake@company.com',
            ServiceNumber: '123455678'
          }
        end
        let(:profile) do
          AskVAApi::Profile::Entity.new(info)
        end
        let(:body) do
          {
            data: {
              attributes: {
                name: 'Fake School'
              }
            }
          }
        end
        let(:gids_response) do
          GI::GIDSResponse.new(status: 200, body:)
        end

        before do
          allow_any_instance_of(AskVAApi::Profile::Retriever).to receive(:call).and_return(profile)
          allow_any_instance_of(GI::Client).to receive(:get_institution_details_v0).and_return(gids_response)
        end

        it 'prefills 0873' do
          VCR.use_cassette('va_profile/demographics/demographics', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                             allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
              expect_prefilled('0873')
            end
          end
        end
      end

      context 'with VA Profile prefill for 10203' do
        before do
          can_prefill_vaprofile(true)
          expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        end

        it 'prefills 10203' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                           allow_playback_repeats: true) do
            expect_prefilled('22-10203')
          end
        end
      end

      context 'with VA Profile and GiBillStatus prefill for 10203' do
        before do
          can_prefill_vaprofile(true)
          expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
          v22_10203_expected['remainingEntitlement'] = {
            'months' => 0,
            'days' => 10
          }
          v22_10203_expected['schoolName'] = 'OLD DOMINION UNIVERSITY'
          v22_10203_expected['schoolCity'] = 'NORFOLK'
          v22_10203_expected['schoolState'] = 'VA'
          v22_10203_expected['schoolCountry'] = 'USA'
        end

        it 'prefills 10203 with VA Profile and entitlement information' do
          VCR.use_cassette('evss/pciu_address/address_domestic') do
            VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
              VCR.use_cassette('form_10203/gi_bill_status_200_response') do
                VCR.use_cassette('gi_client/gets_the_institution_details') do
                  VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                   allow_playback_repeats: true) do
                    expect(BenefitsEducation::Service).to receive(:new).with(user.icn).and_call_original

                    prefilled_data = Oj.load(
                      described_class.for(form_id: '22-10203', user:).prefill.to_json
                    )['form_data']
                    actual = form_profile.send(:clean!, v22_10203_expected)
                    expect(prefilled_data).to eq(actual)
                  end
                end
              end
            end
          end
        end
      end

      context 'with a user that can prefill VA Profile' do
        before do
          can_prefill_vaprofile(true)
        end

        context 'with a user with no vet360_id' do
          before do
            allow(user).to receive(:vet360_id).and_return(nil)
          end

          it 'omits address fields in 686c-674 form' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                             allow_playback_repeats: true) do
              prefilled_data = described_class.for(form_id: '686C-674', user:).prefill[:form_data]
              v686_c_674_expected['veteranContactInformation'].delete('veteranAddress')
              expect(prefilled_data).to eq(v686_c_674_expected)
            end
          end
        end

        %w[
          22-1990
          22-1990N
          22-1990E
          22-1995
          22-5490
          22-5495
          40-10007
          1010ez
          22-0993
          FEEDBACK-TOOL
          686C-674
          28-8832
          28-1900
          26-1880
          26-4555
        ].each do |form_id|
          it "returns prefilled #{form_id}" do
            VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                             allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
              expect_prefilled(form_id)
            end
          end
        end

        context 'with a user that can prefill evss' do
          before do
            allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('usyergd')
          end

          # NOTE: `increase only` and `all claims` use the same form prefilling
          context 'when Vet360 prefill is disabled' do
            before do
              expect(user).to receive(:authorize).with(:ppiu, :access?).and_return(true).at_least(:once)
              expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
            end

            it 'returns prefilled 21-526EZ' do
              Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND)
              Flipper.disable(:disability_compensation_remove_pciu)
              Flipper.enable(:disability_526_toxic_exposure, user)
              VCR.use_cassette('evss/pciu_address/address_domestic') do
                VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
                  VCR.use_cassette('evss/ppiu/payment_information') do
                    VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                                     allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
                      VCR.use_cassette('virtual_regional_office/max_ratings') do
                        expect_prefilled('21-526EZ')
                      end
                    end
                  end
                end
              end
            end
          end
        end

        context 'without ppiu' do
          context 'when Vet360 prefill is enabled' do
            before do
              VAProfile::Configuration::SETTINGS.prefill = true # TODO: - is this missing in the failures above?
              expected_veteran_info = v21_526_ez_expected['veteran']
              expected_veteran_info['emailAddress'] =
                VAProfileRedis::ContactInformation.for_user(user).email.email_address
              expected_veteran_info['primaryPhone'] = '3035551234'
            end

            after do
              VAProfile::Configuration::SETTINGS.prefill = false
            end

            it 'returns prefilled 21-526EZ' do
              Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND)
              Flipper.enable(:disability_526_toxic_exposure, user)
              expect(user).to receive(:authorize).with(:ppiu, :access?).and_return(true).at_least(:once)
              expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
              VCR.use_cassette('evss/pciu_address/address_domestic') do
                VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
                  VCR.use_cassette('evss/ppiu/payment_information') do
                    VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                                     allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
                      VCR.use_cassette('virtual_regional_office/max_ratings') do
                        expect_prefilled('21-526EZ')
                      end
                    end
                  end
                end
              end
            end
          end

          it 'returns prefilled 21-686C' do
            expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
            VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                expect_prefilled('21-686C')
              end
            end
          end
        end
      end
    end

    context 'with a burial application form' do
      it 'returns the va profile mapped to the burial form' do
        expect_prefilled('21P-530')
      end

      context 'without address' do
        let(:v21_p_530_expected) do
          {
            'claimantFullName' => {
              'first' => user.first_name&.capitalize,
              'middle' => user.middle_name&.capitalize,
              'last' => user.last_name&.capitalize,
              'suffix' => user.suffix
            }
          }
        end

        before do
          allow_any_instance_of(FormProfiles::VA21p530)
            .to receive(:initialize_contact_information).and_return(FormContactInformation.new)
        end

        it "doesn't throw an exception" do
          expect_prefilled('21P-530')
        end
      end
    end

    context 'with a higher level review form' do
      let(:schema_name) { '20-0996' }
      let(:schema) { VetsJsonSchema::SCHEMAS[schema_name] }

      let(:form_profile) { described_class.for(form_id: schema_name, user:) }
      let(:prefill) { Oj.load(form_profile.prefill.to_json)['form_data'] }

      before do
        allow_any_instance_of(BGS::People::Service).to(
          receive(:find_person_by_participant_id).and_return(BGS::People::Response.new({ file_nbr: '1234567890' }))
        )
        allow_any_instance_of(VAProfile::Models::Address).to(
          receive(:address_line3).and_return('suite 500')
        )
      end

      it 'street3 returns VAProfile address_line3' do
        expect(form_profile.send(:vet360_mailing_address)&.address_line3).to eq form_profile.send :street3
      end

      it 'prefills' do
        expect(prefill.dig('data', 'attributes', 'veteran', 'address', 'zipCode5')).to be_a(String).or be_nil
        expect(prefill.dig('data', 'attributes', 'veteran', 'phone', 'areaCode')).to be_a(String).or be_nil
        expect(prefill.dig('data', 'attributes', 'veteran', 'phone', 'phoneNumber')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'street')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'street2')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'street3')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'city')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'state')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'country')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranAddress', 'postalCode')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranSsnLastFour')).to be_a(String).or be_nil
        expect(prefill.dig('nonPrefill', 'veteranVaFileNumberLastFour')).to be_a(String)
      end

      it 'prefills an object that passes the schema' do
        full_example = VetsJsonSchema::EXAMPLES['HLR-CREATE-REQUEST-BODY']
        test_data = full_example.deep_merge prefill
        errors = JSON::Validator.fully_validate(
          schema,
          test_data,
          validate_schema: true
        )
        expect(errors.empty?).to eq(true), "schema errors: #{errors}"
      end
    end

    context 'with a notice of disagreement (NOD) form' do
      let(:schema_name) { '10182' }
      let(:schema) do
        DecisionReview::Schemas::NOD_CREATE_REQUEST.merge '$schema': 'http://json-schema.org/draft-04/schema#'
      end

      let(:form_profile) { described_class.for(form_id: schema_name, user:) }
      let(:prefill) { Oj.load(form_profile.prefill.to_json)['form_data'] }

      before do
        allow_any_instance_of(BGS::People::Service).to(
          receive(:find_person_by_participant_id).and_return(BGS::People::Response.new({ file_nbr: '1234567890' }))
        )
        allow_any_instance_of(VAProfile::Models::Address).to(
          receive(:address_line3).and_return('suite 500')
        )
      end

      it 'street3 returns VAProfile address_line3' do
        expect(form_profile.send(:vet360_mailing_address)&.address_line3).to eq form_profile.send :street3
      end

      it 'prefills' do
        veteran = prefill.dig 'data', 'attributes', 'veteran'
        address = veteran['address']
        phone = veteran['phone']
        expect(address['addressLine1']).to be_a String
        expect(address['addressLine2']).to be_a(String).or be_nil
        expect(address['addressLine3']).to be_a(String).or be_nil
        expect(address['city']).to be_a String
        expect(address['stateCode']).to be_a String
        expect(address['zipCode5']).to be_a String
        expect(address['countryName']).to be_a String
        expect(address['internationalPostalCode']).to be_a(String).or be_nil
        expect(phone['areaCode']).to be_a String
        expect(phone['phoneNumber']).to be_a String
        expect(veteran['emailAddressText']).to be_a String
        non_prefill = prefill['nonPrefill']
        expect(non_prefill['veteranSsnLastFour']).to be_a String
        expect(non_prefill['veteranVaFileNumberLastFour']).to be_a String
      end

      it 'prefills an object that passes the schema' do
        full_example = JSON.parse File.read Rails.root.join 'spec', 'fixtures', 'notice_of_disagreements',
                                                            'valid_NOD_create_request.json'

        test_data = full_example.deep_merge prefill.except('nonPrefill')
        errors = JSON::Validator.fully_validate(
          schema,
          test_data,
          validate_schema: true
        )
        expect(errors.empty?).to eq(true), "schema errors: #{errors}"
      end
    end

    context 'with a pension application form' do
      it 'returns the va profile mapped to the pension form' do
        expect_prefilled('21P-527EZ')
      end
    end

    context 'when the form mapping can not be found' do
      it 'raises an IOError' do
        allow(FormProfile).to receive(:prefill_enabled_forms).and_return(['foo'])

        expect { described_class.new(form_id: 'foo', user:).prefill }.to raise_error(IOError)
      end
    end

    context 'when the form does not use prefill' do
      it 'does not raise an error' do
        expect { described_class.new(form_id: '21-4142', user:).prefill }.not_to raise_error
      end
    end
  end

  describe '.mappings_for_form' do
    context 'with multiple form profile instances' do
      let(:instance1) { FormProfile.new(form_id: '1010ez', user:) }
      let(:instance2) { FormProfile.new(form_id: '1010ez', user:) }

      it 'loads the yaml file only once' do
        expect(YAML).to receive(:load_file).once.and_return(
          'veteran_full_name' => %w[identity_information full_name],
          'gender' => %w[identity_information gender],
          'veteran_date_of_birth' => %w[identity_information date_of_birth],
          'veteran_address' => %w[contact_information address],
          'home_phone' => %w[contact_information home_phone]
        )
        instance1.prefill
        instance2.prefill
      end
    end

    context '10-7959F-1 form profile instances' do
      let(:instance) { FormProfile.new(form_id: '10-7959F-1', user:) }

      it 'loads the yaml file only once' do
        expect(YAML).to receive(:load_file).once.and_return(
          'veteranFullName' => %w[identity_information full_name],
          'veteranAddress' => %w[contact_information address],
          'veteranSocialSecurityNumber' => %w[identity_information ssn],
          'veteranPhoneNumber' => %w[contact_information us_phone],
          'veteranEmailAddress' => %w[contact_information email],
          'veteranPhysicalAddress' => %w[residential_address]
        )
        instance.prefill
      end
    end
  end
end
