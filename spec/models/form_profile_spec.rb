# frozen_string_literal: true

require 'rails_helper'
require 'decision_review/schemas'
require 'disability_compensation/factories/api_provider_factory'
require 'gi/client'

RSpec.describe FormProfile, type: :model do
  include SchemaMatchers

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:dependents_module_enabled, anything).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:disability_526_max_cfi_service_switch, anything).and_return(false)
    described_class.instance_variable_set(:@mappings, nil)
  end

  let(:user) do
    build(:user, :loa3, :legacy_icn, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef', suffix: 'Jr.',
                                     address: build(:va_profile_address), vet360_id: '1')
  end

  let(:contact_info) { form_profile.send :initialize_contact_information }
  let(:form_profile) do
    described_class.new(form_id: 'foo', user:)
  end
  let(:va_profile_address) { contact_info&.address }
  let(:us_phone) { contact_info&.home_phone }
  let(:mobile_phone) { contact_info&.mobile_phone }
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
      'street' => va_profile_address.street,
      'street2' => va_profile_address.street2,
      'city' => va_profile_address.city,
      'state' => va_profile_address.state,
      'country' => va_profile_address.country,
      'postal_code' => va_profile_address.postal_code
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
          'ssn' => user.ssn,
          'email' => user.va_profile_email,
          'phoneNumber' => us_phone
        }
      }
    }
  end
  let(:v0873_expected) do
    user_work_phone = user.vet360_contact_info.work_phone
    work_phone = [
      user_work_phone.country_code,
      user_work_phone.area_code,
      user_work_phone.phone_number,
      user_work_phone.extension
    ].compact.join

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
        'email' => user.va_profile_email,
        'phone' => us_phone,
        'address' => address,
        'workPhone' => work_phone
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
        'phoneNumber' => '3035551234',
        'emailAddress' => user.va_profile_email
      },
      'nonPrefill' => {
        'veteranSsnLastFour' => '1863',
        'veteranVaFileNumberLastFour' => '1863'
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

  let(:v686_c_674_v2_expected) do
    {
      'veteranContactInformation' => {
        'veteranAddress' => {
          'street' => '140 Rock Creek Rd',
          'country' => 'USA',
          'city' => 'Washington',
          'state' => 'DC',
          'postalCode' => '20011'
        },
        'phoneNumber' => us_phone,
        'emailAddress' => user.va_profile_email
      },
      'nonPrefill' => {
        'veteranSsnLastFour' => '1863',
        'veteranVaFileNumberLastFour' => '1863',
        'isInReceiptOfPension' => -1,
        'netWorthLimit' => 163_699
      },
      'veteranInformation' => {
        'fullName' => {
          'first' => user.first_name.capitalize,
          'last' => user.last_name.capitalize
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
      'veteranAddress' => address,
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'gender' => user.gender,
      'homePhone' => us_phone,
      'mobilePhone' => mobile_phone,
      'veteranDateOfBirth' => user.birth_date,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.va_profile_email
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
      'mailingAddress' => address,
      'applicantFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'applicantGender' => user.gender,
      'dayTimePhone' => us_phone,
      'nightTimePhone' => mobile_phone,
      'dateOfBirth' => user.birth_date,
      'applicantSocialSecurityNumber' => user.ssn,
      'emailAddress' => user.va_profile_email
    }
  end
  let(:v22_1990_n_expected) do
    {
      'toursOfDuty' => tours_of_duty,
      'currentlyActiveDuty' => {
        'yes' => false
      },
      'veteranAddress' => address,
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
      'email' => user.va_profile_email
    }
  end
  let(:v22_1990_e_expected) do
    {
      'relativeAddress' => address,
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
      'veteranAddress' => address,
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.va_profile_email
    }
  end
  let(:v22_1995_s_expected) do
    {
      'veteranAddress' => address,
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'homePhone' => us_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.va_profile_email
    }
  end
  let(:v22_10203_expected) do
    {
      'veteranAddress' => address,
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'homePhone' => us_phone,
      'mobilePhone' => mobile_phone,
      'veteranSocialSecurityNumber' => user.ssn,
      'email' => user.va_profile_email
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
      'email' => user.va_profile_email,
      'veteranAddress' => address,
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
        'emailAddress' => user.va_profile_email,
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
      'email' => user.va_profile_email,
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
      'veteranAddress' => address,
      'email' => user.va_profile_email,
      'phone' => us_phone,
      'mobilePhone' => mobile_phone,
      'internationalPhone' => '3035551234',
      'serviceBranch' => {
        'army' => true,
        'airForce' => true
      },
      'activeServiceDateRange' => {
        'from' => '1984-08-01',
        'to' => '2014-08-31'
      },
      'serviceNumber' => '796111863',
      'veteranSocialSecurityNumber' => user.ssn,
      'veteranDateOfBirth' => user.birth_date
    }
  end

  let(:v21_p_530_ez_expected) do
    {
      'claimantFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'claimantAddress' => address,
      'claimantPhone' => us_phone,
      'claimantEmail' => user.va_profile_email
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
          'ratingDecisionId' => '0',
          'ratingPercentage' => 50
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
        'primaryPhone' => '3035551234',
        'emailAddress' => 'person101@example.com'
      },
      'bankAccountNumber' => '******7890',
      'bankAccountType' => 'Checking',
      'bankName' => 'WELLS FARGO BANK',
      'bankRoutingNumber' => '*****0503',
      'startedFormVersion' => '2022',
      'syncModern0781Flow' => true,
      'disabilityCompNewConditionsWorkflow' => true
    }
  end
  let(:vfeedback_tool_expected) do
    {
      'address' => {
        'street' => va_profile_address.street,
        'street2' => va_profile_address.street2,
        'city' => va_profile_address.city,
        'state' => va_profile_address.state,
        'country' => 'US',
        'postal_code' => va_profile_address.postal_code
      },
      'serviceBranch' => 'Army',
      'fullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => user.middle_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.suffix
      },
      'applicantEmail' => user.va_profile_email,
      'phone' => us_phone,
      'serviceDateRange' => {
        'from' => '2002-07-02',
        'to' => '2014-08-31'
      }
    }
  end

  let(:v21_2680_expected) do
    { userInformation: {
      fullName: {
        first: 'Abraham',
        last: 'Lincoln',
        suffix: 'Jr.'
      },
      dob: '1809-02-12',
      phoneNumber: '3035551234',
      email: user.va_profile_email,
      address: {
        street: '140 Rock Creek Rd',
        city: 'Washington',
        state: 'DC',
        country: 'USA',
        postalCode: '20011'
      }
    } }
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
      'applicantAddress' => address,
      'contactPhone' => us_phone,
      'contactEmail' => user.va_profile_email,
      'periodsOfService' => tours_of_duty,
      'currentlyActiveDuty' => {
        'yes' => false
      },
      'activeDuty' => false
    }
  end
  let(:v28_8832_expected) do
    {
      'claimantAddress' => address,
      'claimantPhoneNumber' => us_phone,
      'claimantEmailAddress' => user.va_profile_email
    }
  end
  let(:vform_mock_ae_design_patterns_expected) do
    {
      'data' => {
        'attributes' => {
          'veteran' => {
            'firstName' => user.first_name&.capitalize,
            'middleName' => user.middle_name&.capitalize,
            'lastName' => user.last_name&.capitalize,
            'suffix' => user.suffix,
            'dateOfBirth' => user.birth_date,
            'ssn' => user.ssn.last(4),
            'gender' => user.gender,
            'address' => {
              'addressLine1' => va_profile_address.street,
              'addressLine2' => va_profile_address.street2,
              'city' => va_profile_address.city,
              'stateCode' => va_profile_address.state,
              'countryName' => va_profile_address.country,
              'zipCode5' => va_profile_address.postal_code
            },
            'phone' => {
              'areaCode' => us_phone[0..2],
              'phoneNumber' => us_phone[3..9]
            },
            'homePhone' => '3035551234',
            'mobilePhone' => mobile_phone,
            'emailAddressText' => user.va_profile_email,
            'lastServiceBranch' => 'Army'
          }
        }
      }
    }
  end
  let(:vform_mock_prefill_expected) do
    {
      'data' => {
        'attributes' => {
          'veteran' => {
            'firstName' => user.first_name&.capitalize,
            'middleName' => user.middle_name&.capitalize,
            'lastName' => user.last_name&.capitalize,
            'suffix' => user.suffix,
            'dateOfBirth' => user.birth_date,
            'ssn' => user.ssn.last(4),
            'gender' => user.gender,
            'address' => {
              'addressLine1' => va_profile_address.street,
              'addressLine2' => va_profile_address.street2,
              'city' => va_profile_address.city,
              'stateCode' => va_profile_address.state,
              'countryName' => va_profile_address.country,
              'zipCode5' => va_profile_address.postal_code
            },
            'phone' => {
              'areaCode' => us_phone[0..2],
              'phoneNumber' => us_phone[3..9]
            },
            'homePhone' => '3035551234',
            'mobilePhone' => mobile_phone,
            'emailAddressText' => user.va_profile_email,
            'lastServiceBranch' => 'Army'
          }
        }
      }
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
      'veteranAddress' => address,
      'mainPhone' => us_phone,
      'email' => user.va_profile_email,
      'cellPhone' => mobile_phone
    }
  end
  let(:v21_22_expected) do
    {
      'personalInformation' => {
        'fullName' => {
          'first' => user.first_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'ssn' => '796111863',
        'dateOfBirth' => '1809-02-12'
      },
      'contactInformation' => {
        'email' => user.va_profile_email,
        'address' => address,
        'primaryPhone' => '3035551234'
      },
      'militaryInformation' => {
        'serviceBranch' => 'Army',
        'serviceDateRange' => {
          'from' => '2002-07-02',
          'to' => '2014-08-31'
        }
      },
      'identityValidation' => {
        'hasICN' => true,
        'hasParticipantId' => true,
        'isLoa3' => true
      }
    }
  end
  let(:v21_22_a_expected) do
    {
      'personalInformation' => {
        'fullName' => {
          'first' => user.first_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'ssn' => '796111863',
        'dateOfBirth' => '1809-02-12'
      },
      'contactInformation' => {
        'email' => user.va_profile_email,
        'address' => address,
        'primaryPhone' => '3035551234'
      },
      'militaryInformation' => {
        'serviceBranch' => 'Army',
        'serviceDateRange' => {
          'from' => '2002-07-02',
          'to' => '2014-08-31'
        }
      },
      'identityValidation' => {
        'hasICN' => true,
        'hasParticipantId' => true,
        'isLoa3' => true
      }
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
        'homePhone' => us_phone,
        'mobilePhone' => mobile_phone,
        'email' => user.va_profile_email,
        'address' => address
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
        'homePhone' => '13035551234',
        'email' => user.va_profile_email,
        'address' => address
      }
    }
  end

  let(:vdispute_debt_expected) do
    {
      'veteran' => {
        'fullName' => {
          'first' => user.first_name&.capitalize,
          'last' => user.last_name&.capitalize,
          'suffix' => user.suffix
        },
        'ssn' => '1863',
        'dateOfBirth' => '1809-02-12',
        'homePhone' => us_phone,
        'email' => user.va_profile_email,
        'fileNumber' => '3735'
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
          output = form_profile.send(:initialize_military_information).attribute_values.transform_keys(&:to_s)

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
          expect(actual_service_histories.map(&:attributes)).to match(expected_service_histories)

          first_item = actual_guard_reserve_service_history.map(&:attributes).first
          expect(first_item['from'].to_s).to eq(expected_guard_reserve_service_history.first[:from])
          expect(first_item['to'].to_s).to eq(expected_guard_reserve_service_history.first[:to])

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
        expect(form_profile).to receive(:log_exception_to_rails)
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
        expect(actual_service_histories.map(&:attributes)).to match(expected_service_histories)
      end
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
      when '1010ez', 'FORM-MOCK-AE-DESIGN-PATTERNS', 'FORM-MOCK-PREFILL'
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

        expect(errors.empty?).to be(true), "schema errors: #{errors}"
      end

      expect(prefilled_data).to eq(
        form_profile.send(:clean!, public_send("v#{form_id.underscore}_expected"))
      )
    end

    context 'with a user that can prefill 10-10EZR' do
      let(:form_profile) do
        FormProfiles::VA1010ezr.new(user:, form_id: 'f')
      end
      let(:ezr_prefilled_data_without_ee_data) do
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
          'veteranAddress' => address,
          'email' => user.va_profile_email
        }
      end

      context 'when the ee service is down' do
        let(:v10_10_ezr_expected) { ezr_prefilled_data_without_ee_data.merge('nonPrefill' => {}) }

        it 'prefills the rest of the data and logs exception to sentry' do
          expect_any_instance_of(FormProfiles::VA1010ezr).to receive(:log_exception_to_sentry).with(
            instance_of(VCR::Errors::UnhandledHTTPRequestError)
          )
          expect_prefilled('10-10EZR')
        end
      end

      context 'with a user with financial data, insurance data, and dependents',
              run_at: 'Thu, 27 Feb 2025 01:10:06 GMT' do
        before do
          allow(user).to receive(:icn).and_return('1012829228V424035')
          allow(Flipper).to receive(:enabled?).and_call_original
        end

        context "when the 'ezr_form_prefill_with_providers_and_dependents' flipper is enabled" do
          before do
            allow(Flipper).to receive(:enabled?).with(:ezr_form_prefill_with_providers_and_dependents).and_return(true)
            allow(Flipper).to receive(:enabled?).with(:ezr_emergency_contacts_enabled,
                                                      instance_of(User)).and_return(false)
          end

          let(:v10_10_ezr_expected) do
            JSON.parse(
              File.read('spec/fixtures/form1010_ezr/veteran_data.json')
            ).merge(ezr_prefilled_data_without_ee_data).except('nextOfKins', 'emergencyContacts')
          end

          it 'returns a prefilled 10-10EZR form', run_at: 'Thu, 27 Feb 2025 01:10:06 GMT' do
            VCR.use_cassette(
              'form1010_ezr/lookup_user_with_ezr_prefill_data',
              match_requests_on: %i[method uri body], erb: true
            ) do
              expect_prefilled('10-10EZR')
            end
          end

          context "and the 'ezr_emergency_contacts_enabled' flipper is enabled" do
            before do
              allow(Flipper).to receive(:enabled?).with(:ezr_emergency_contacts_enabled,
                                                        instance_of(User)).and_return(true)
            end

            let(:v10_10_ezr_expected) do
              contacts = JSON.parse(
                File.read('spec/fixtures/form1010_ezr/veteran_data.json')
              ).merge(ezr_prefilled_data_without_ee_data)
              contacts
            end

            it 'returns a prefilled 10-10EZR form', run_at: 'Thu, 27 Feb 2025 01:10:06 GMT' do
              VCR.use_cassette(
                'form1010_ezr/lookup_user_with_ezr_prefill_data',
                match_requests_on: %i[method uri body], erb: true
              ) do
                expect_prefilled('10-10EZR')
              end
            end
          end
        end

        context "when the 'ezr_form_prefill_with_providers_and_dependents' flipper is disabled" do
          before do
            allow(Flipper).to receive(:enabled?).with(
              :ezr_form_prefill_with_providers_and_dependents
            ).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:ezr_emergency_contacts_enabled,
                                                      instance_of(User)).and_return(false)
          end

          let(:v10_10_ezr_expected) do
            JSON.parse(
              File.read('spec/fixtures/form1010_ezr/veteran_data.json')
            ).merge(ezr_prefilled_data_without_ee_data).except(
              'providers',
              'dependents',
              'nextOfKins',
              'emergencyContacts'
            )
          end

          it 'returns a prefilled 10-10EZR form that does not include providers, dependents, or contacts',
             run_at: 'Thu, 27 Feb 2025 01:10:06 GMT' do
            VCR.use_cassette(
              'form1010_ezr/lookup_user_with_ezr_prefill_data',
              match_requests_on: %i[method uri body], erb: true
            ) do
              expect_prefilled('10-10EZR')
            end
          end

          context "and the 'ezr_emergency_contacts_enabled' flipper is enabled" do
            before do
              allow(Flipper).to receive(:enabled?).with(:ezr_emergency_contacts_enabled,
                                                        instance_of(User)).and_return(true)
            end

            let(:v10_10_ezr_expected) do
              JSON.parse(
                File.read('spec/fixtures/form1010_ezr/veteran_data.json')
              ).merge(ezr_prefilled_data_without_ee_data).except('providers', 'dependents')
            end

            it 'returns a prefilled 10-10EZR form', run_at: 'Thu, 27 Feb 2025 01:10:06 GMT' do
              VCR.use_cassette(
                'form1010_ezr/lookup_user_with_ezr_prefill_data',
                match_requests_on: %i[method uri body], erb: true
              ) do
                expect_prefilled('10-10EZR')
              end
            end
          end
        end
      end
    end

    context 'with a user that can prefill mdot' do
      before do
        expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
        expect(user).to receive(:authorize).with(:mdot, :access?).and_return(true).at_least(:once)
        expect(user).to receive(:authorize).with(:va_profile, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:mdot, :access?)).to be(true)
      end

      it 'returns a prefilled MDOT form', :skip_va_profile do
        VCR.use_cassette('mdot/get_supplies_200') do
          expect_prefilled('MDOT')
        end
      end
    end

    context 'with a user that can prefill DisputeDebt' do
      before do
        allow_any_instance_of(BGS::People::Service).to(
          receive(:find_person_by_participant_id).and_return(BGS::People::Response.new({ file_nbr: '796043735' }))
        )
      end

      it 'returns a prefilled DisputeDebt form' do
        expect_prefilled('DISPUTE-DEBT')
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
                'emailAddress' => user.va_profile_email,
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
          expect(output['currently_active_duty']).to be(false)
          expect(output['currently_active_duty_hash']).to match({ yes: false })
          expect(output['discharge_type']).to be_nil
          expect(output['guard_reserve_service_history']).to eq([])
          expect(output['hca_last_service_branch']).to eq('other')
          expect(output['last_discharge_date']).to be_nil
          expect(output['last_entry_date']).to be_nil
          expect(output['last_service_branch']).to be_nil
          expect(output['latest_guard_reserve_service_period']).to be_nil
          expect(output['post_nov111998_combat']).to be(false)
          expect(output['service_branches']).to eq([])
          expect(output['service_episodes_by_date']).to eq([])
          expect(output['service_periods']).to eq([])
          expect(output['sw_asia_combat']).to be(false)
          expect(output['tours_of_duty']).to eq([])
        end
      end
    end

    context 'when VA Profile returns 500', :skip_va_profile do
      it 'sends a BackendServiceException to Sentry and returns and empty hash' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500',
                         allow_playback_repeats: true, match_requests_on: %i[method uri]) do
          expect(form_profile).to receive(:log_exception_to_rails)
          expect(form_profile.send(:initialize_va_profile_prefill_military_information)).to eq({})
        end
      end
    end

    context 'with military information data', :skip_va_profile do
      context 'with va profile prefill on' do
        before do
          VAProfile::Configuration::SETTINGS.prefill = true
          v22_1990_expected['email'] = VAProfileRedis::V2::ContactInformation.for_user(user).email.email_address
          v22_1990_expected['homePhone'] = '3035551234'
          v22_1990_expected['mobilePhone'] = '3035551234'
          v22_1990_expected['veteranAddress'] = address
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
          expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
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
          expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:ppiu, :access?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        end

        it 'prefills 0994 with VA Profile and payment information' do
          VCR.use_cassette('va_profile/v2/contact_information/get_address') do
            VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                expect_prefilled('22-0994')
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

        context 'when CRM profile is working' do
          it 'prefills 0873' do
            VCR.use_cassette('va_profile/demographics/demographics', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
                expect_prefilled('0873')
              end
            end
          end
        end

        context 'when school facility code is nil' do
          let(:info) do
            {
              SchoolFacilityCode: nil,
              BusinessPhone: '1234567890',
              BusinessEmail: 'fake@company.com',
              ServiceNumber: '123455678'
            }
          end
          let(:v0873_expected) do
            {
              'personalInformation' => {
                'first' => user.first_name&.capitalize,
                'last' => user.last_name&.capitalize,
                'suffix' => user.suffix,
                'preferredName' => 'SAM',
                'dateOfBirth' => user.birth_date,
                'socialSecurityNumber' => user.ssn,
                'serviceNumber' => '123455678'
              },
              'contactInformation' => {
                'email' => user.va_profile_email,
                'phone' => us_phone,
                'workPhone' => '13035551234',
                'address' => address
              },
              'avaProfile' => {
                'businessPhone' => '1234567890',
                'businessEmail' => 'fake@company.com'
              },
              'veteranServiceInformation' => veteran_service_information
            }
          end

          it 'does not show in ava profile' do
            VCR.use_cassette('va_profile/demographics/demographics', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
                expect_prefilled('0873')
              end
            end
          end
        end
      end

      context 'with VA Profile prefill for 10203' do
        before do
          allow(Flipper).to receive(:enabled?).with(:form_10203_claimant_service).and_return(false)
          expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:lighthouse, :access?).and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:va_profile, :access?).and_return(true).at_least(:once)
        end

        it 'prefills 10203' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                           allow_playback_repeats: true) do
            expect_prefilled('22-10203')
          end
        end
      end

      context 'with VA Profile and GiBillStatus prefill for 10203' do
        context 'when form 10203 claimant flipper enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:form_10203_claimant_service).and_return(true)
            expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
            can_prefill_vaprofile(true)
            expect(user).to receive(:authorize).with(:dgi, :access?).and_return(true).at_least(:once)
            v22_10203_expected['remainingEntitlement'] = {
              'months' => 0,
              'days' => 0
            }
            v22_10203_expected['schoolName'] = 'OLD DOMINION UNIVERSITY'
            v22_10203_expected['schoolCity'] = 'NORFOLK'
            v22_10203_expected['schoolState'] = 'VA'
            v22_10203_expected['schoolCountry'] = 'USA'
          end

          it 'prefills 10203 with VA Profile and entitlement information' do
            VCR.use_cassette('va_profile/v2/contact_information/get_address') do
              VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
                VCR.use_cassette('sob/ch33_status/200_with_enrollments') do
                  VCR.use_cassette('gi_client/gets_the_institution_details') do
                    expect(SOB::DGI::Service).to receive(:new).with(ssn: user.ssn, include_enrollments: true)
                                                              .and_call_original

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

        context 'when form 10203 claimant flipper disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:form_10203_claimant_service).and_return(false)
            expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
            can_prefill_vaprofile(true)
            expect(user).to receive(:authorize).with(:lighthouse, :access?).and_return(true).at_least(:once)
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
            VCR.use_cassette('va_profile/v2/contact_information/get_address') do
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
      end

      context 'with a user that can prefill VA Profile' do
        before do
          can_prefill_vaprofile(true)
        end

        context 'with a 686c-674 form v3 enabled' do
          let(:v686_c_674_v2_expected) do
            {
              'veteranContactInformation' => {
                'veteranAddress' => {
                  'street' => '140 Rock Creek Rd',
                  'country' => 'USA',
                  'city' => 'Washington',
                  'state' => 'DC',
                  'postalCode' => '20011'
                },
                'phoneNumber' => us_phone,
                'emailAddress' => user.va_profile_email
              },
              'nonPrefill' => {
                'dependents' => {
                  'success' => 'false'
                },
                'veteranSsnLastFour' => '1863',
                'veteranVaFileNumberLastFour' => '1863',
                'isInReceiptOfPension' => -1,
                'netWorthLimit' => 163_699
              },
              'veteranInformation' => {
                'fullName' => {
                  'first' => user.first_name.capitalize,
                  'last' => user.last_name.capitalize
                },
                'ssn' => '796111863',
                'birthDate' => '1809-02-12'
              }
            }
          end

          before do
            expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
            allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(true)
          end

          context 'with a 686c-674 v1 form' do
            it 'omits address fields in 686c-674 form' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                expect_prefilled('686C-674')
              end
            end
          end

          context 'with a 686c-674-v2 form' do
            it 'omits address fields in 686c-674-V2 form' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                expect_prefilled('686C-674-V2')
              end
            end

            context 'with pension awards prefill' do
              let(:user) { create(:evss_user, :loa3) }
              let(:form_profile) do
                FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
              end

              before do
                allow(Rails.logger).to receive(:warn)
              end

              it 'prefills net worth limit with default value when using get_current_awards' do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  # Mock get_current_awards to return IP award line type
                  mock_response_body = {
                    'award' => {
                      'award_event_list' => {
                        'award_events' => [
                          {
                            'award_line_list' => {
                              'award_lines' => [
                                {
                                  'award_line_type' => 'IP',
                                  'effective_date' => '2020-01-01T00:00:00-05:00'
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  }
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                    OpenStruct.new(body: mock_response_body)
                  )

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]
                  expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
                end
              end

              it 'prefills 1 when user is in receipt of pension (IP award line type)' do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  # Mock get_current_awards to return IP award line type with effective date before today
                  mock_response_body = {
                    'award' => {
                      'award_event_list' => {
                        'award_events' => [
                          {
                            'award_line_list' => {
                              'award_lines' => [
                                {
                                  'award_line_type' => 'IP',
                                  'effective_date' => '2020-01-01T00:00:00-05:00'
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  }
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                    OpenStruct.new(body: mock_response_body)
                  )

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                  expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(1)
                end
              end

              it 'prefills 0 when user has non-IP award line type (not receiving pension)' do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  # Mock get_current_awards to return non-IP award line type
                  mock_response_body = {
                    'award' => {
                      'award_event_list' => {
                        'award_events' => [
                          {
                            'award_line_list' => {
                              'award_lines' => [
                                {
                                  'award_line_type' => 'COMP',
                                  'effective_date' => '2020-01-01T00:00:00-05:00'
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  }
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                    OpenStruct.new(body: mock_response_body)
                  )

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                  expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(0)
                end
              end

              it 'prefills -1 and default net worth limit when bid awards service returns an error' do
                error = StandardError.new('awards pension error')
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_raise(error)
                  monitor = instance_double(Dependents::Monitor)
                  allow(Dependents::Monitor).to receive(:new).and_return(monitor)
                  allow(monitor).to receive(:track_event)

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                  expect(monitor)
                    .to have_received(:track_event)
                    .with(
                      'warn', 'Failed to retrieve awards pension data', 'awards_pension_error', {
                        user_account_uuid: user&.user_account_uuid,
                        error: error.message,
                        form_id: '686C-674-V2'
                      }
                    )

                  expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(-1)
                  expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
                end
              end
            end

            context 'with dependents prefill' do
              let(:user) { create(:evss_user, :loa3) }
              let(:form_profile) do
                FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
              end
              let(:dependent_service) { instance_double(BGS::DependentService) }
              let(:dependents_data) do
                { number_of_records: '1', persons: [{
                  award_indicator: 'Y',
                  date_of_birth: '01/02/1960',
                  email_address: 'test@email.com',
                  first_name: 'JANE',
                  last_name: 'WEBB',
                  middle_name: 'M',
                  ptcpnt_id: '600140899',
                  related_to_vet: 'Y',
                  relationship: 'Spouse',
                  ssn: '222883214',
                  veteran_indicator: 'N'
                }] }
              end
              let(:dependents_information) do
                [{
                  'fullName' => { 'first' => 'JANE', 'middle' => 'M', 'last' => 'WEBB' },
                  'dateOfBirth' => '1960-01-02',
                  'ssn' => '222883214',
                  'relationshipToVeteran' => 'Spouse',
                  'awardIndicator' => 'Y'
                }]
              end

              before do
                allow(Rails.logger).to receive(:warn)
              end

              it 'returns formatted dependent information' do
                # Mock the dependent service to return active dependents
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)

                result = form_profile.prefill
                expect(result[:form_data]).to have_key('veteranInformation')
                expect(result[:form_data]).to have_key('veteranContactInformation')
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).to have_key('dependents')
                expect(result[:form_data]['nonPrefill']['dependents']['dependents']).to eq(dependents_information)
              end

              it 'handles a dependent information error' do
                # Mock the dependent service to return an error
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_raise(
                  StandardError.new('Dependent information error')
                )
                result = form_profile.prefill
                expect(result[:form_data]).to have_key('veteranInformation')
                expect(result[:form_data]).to have_key('veteranContactInformation')
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']['dependents']).not_to have_key('dependents')
              end

              it 'handles missing dependents data' do
                # Mock the dependent service to return no dependents
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(nil)
                result = form_profile.prefill
                expect(result[:form_data]).to have_key('veteranInformation')
                expect(result[:form_data]).to have_key('veteranContactInformation')
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']['dependents']).not_to have_key('dependents')
              end

              it 'handles invalid date formats gracefully' do
                invalid_date_data = dependents_data.dup
                invalid_date_data[:persons][0][:date_of_birth] = 'invalid-date'

                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(invalid_date_data)

                result = form_profile.prefill
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).to have_key('dependents')
                dependents = result[:form_data]['nonPrefill']['dependents']
                expect(dependents).to be_an(Object)
                expect(dependents['dependents'].first['dateOfBirth']).to be_nil
              end

              it 'handles nil date gracefully' do
                nil_date_data = dependents_data.dup
                nil_date_data[:persons][0][:date_of_birth] = nil

                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(nil_date_data)

                result = form_profile.prefill
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).to have_key('dependents')
                dependents = result[:form_data]['nonPrefill']['dependents']
                expect(dependents).to be_an(Object)
                expect(dependents['dependents'].first['dateOfBirth']).to be_nil
              end
            end
          end
        end

        context 'with a 686c-674 form v3 disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(false)
          end

          context 'with a 686c-674 v1 form' do
            before do
              expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
            end

            it 'omits address fields in 686c-674 form' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                expect_prefilled('686C-674')
              end
            end
          end

          context 'with a 686c-674-v2 form' do
            it 'omits address fields in 686c-674-V2 form' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
                expect_prefilled('686C-674-V2')
              end
            end

            context 'with pension awards prefill' do
              let(:user) { create(:evss_user, :loa3) }
              let(:form_profile) do
                FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
              end

              before do
                expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
                allow(Rails.logger).to receive(:warn)
              end

              it 'prefills net worth limit with default value when using get_current_awards' do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  # Mock get_current_awards to return IP award line type
                  mock_response_body = {
                    'award' => {
                      'award_event_list' => {
                        'award_events' => [
                          {
                            'award_line_list' => {
                              'award_lines' => [
                                {
                                  'award_line_type' => 'IP',
                                  'effective_date' => '2020-01-01T00:00:00-05:00'
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  }
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                    OpenStruct.new(body: mock_response_body)
                  )

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]
                  expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
                end
              end

              it 'prefills 1 when user is in receipt of pension (IP award line type)' do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  # Mock get_current_awards to return IP award line type with effective date before today
                  mock_response_body = {
                    'award' => {
                      'award_event_list' => {
                        'award_events' => [
                          {
                            'award_line_list' => {
                              'award_lines' => [
                                {
                                  'award_line_type' => 'IP',
                                  'effective_date' => '2020-01-01T00:00:00-05:00'
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  }
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                    OpenStruct.new(body: mock_response_body)
                  )

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                  expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(1)
                end
              end

              it 'prefills 0 when user has non-IP award line type (not receiving pension)' do
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  # Mock get_current_awards to return non-IP award line type
                  mock_response_body = {
                    'award' => {
                      'award_event_list' => {
                        'award_events' => [
                          {
                            'award_line_list' => {
                              'award_lines' => [
                                {
                                  'award_line_type' => 'COMP',
                                  'effective_date' => '2020-01-01T00:00:00-05:00'
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  }
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                    OpenStruct.new(body: mock_response_body)
                  )

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                  expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(0)
                end
              end

              it 'prefills -1 and default net worth limit when bid awards service returns an error' do
                error = StandardError.new('awards pension error')
                VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                                 allow_playback_repeats: true) do
                  allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_raise(error)
                  monitor = instance_double(Dependents::Monitor)
                  allow(Dependents::Monitor).to receive(:new).and_return(monitor)
                  allow(monitor).to receive(:track_event)

                  prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                  expect(monitor)
                    .to have_received(:track_event)
                    .with(
                      'warn', 'Failed to retrieve awards pension data', 'awards_pension_error', {
                        user_account_uuid: user&.user_account_uuid,
                        error: error.message,
                        form_id: '686C-674-V2'
                      }
                    )

                  expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(-1)
                  expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
                end
              end
            end

            context 'with dependents prefill' do
              let(:user) { create(:evss_user, :loa3) }
              let(:form_profile) do
                FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
              end
              let(:dependent_service) { instance_double(BGS::DependentService) }
              let(:dependents_data) do
                { number_of_records: '1', persons: [{
                  award_indicator: 'Y',
                  date_of_birth: '01/02/1960',
                  email_address: 'test@email.com',
                  first_name: 'JANE',
                  last_name: 'WEBB',
                  middle_name: 'M',
                  ptcpnt_id: '600140899',
                  related_to_vet: 'Y',
                  relationship: 'Spouse',
                  ssn: '222883214',
                  veteran_indicator: 'N'
                }] }
              end
              let(:dependents_information) do
                [{
                  'fullName' => { 'first' => 'JANE', 'middle' => 'M', 'last' => 'WEBB' },
                  'dateOfBirth' => '1960-01-02',
                  'ssn' => '222883214',
                  'relationshipToVeteran' => 'Spouse',
                  'awardIndicator' => 'Y'
                }]
              end

              before do
                expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
                allow(Rails.logger).to receive(:warn)
              end

              it 'returns formatted dependent information' do
                # Mock the dependent service to return active dependents
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)

                result = form_profile.prefill
                expect(result[:form_data]).to have_key('veteranInformation')
                expect(result[:form_data]).to have_key('veteranContactInformation')
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).to have_key('dependents')
                expect(result[:form_data]['nonPrefill']['dependents']).to eq(dependents_information)
              end

              it 'handles a dependent information error' do
                # Mock the dependent service to return an error
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_raise(
                  StandardError.new('Dependent information error')
                )
                result = form_profile.prefill
                expect(result[:form_data]).to have_key('veteranInformation')
                expect(result[:form_data]).to have_key('veteranContactInformation')
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).not_to have_key('dependents')
              end

              it 'handles missing dependents data' do
                # Mock the dependent service to return no dependents
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(nil)
                result = form_profile.prefill
                expect(result[:form_data]).to have_key('veteranInformation')
                expect(result[:form_data]).to have_key('veteranContactInformation')
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).not_to have_key('dependents')
              end

              it 'handles invalid date formats gracefully' do
                invalid_date_data = dependents_data.dup
                invalid_date_data[:persons][0][:date_of_birth] = 'invalid-date'

                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(invalid_date_data)

                result = form_profile.prefill
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).to have_key('dependents')
                dependents = result[:form_data]['nonPrefill']['dependents']
                expect(dependents).to be_an(Array)
                expect(dependents.first['dateOfBirth']).to be_nil
              end

              it 'handles nil date gracefully' do
                nil_date_data = dependents_data.dup
                nil_date_data[:persons][0][:date_of_birth] = nil

                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return(nil_date_data)

                result = form_profile.prefill
                expect(result[:form_data]).to have_key('nonPrefill')
                expect(result[:form_data]['nonPrefill']).to have_key('dependents')
                dependents = result[:form_data]['nonPrefill']['dependents']
                expect(dependents).to be_an(Array)
                expect(dependents.first['dateOfBirth']).to be_nil
              end
            end

            context 'with address prefill' do
              let(:user) { create(:evss_user, :loa3) }
              let(:form_profile) do
                FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
              end
              let(:contact_info_service) { instance_double(VAProfileRedis::V2::ContactInformation) }
              let(:dependent_service) { instance_double(BGS::DependentService) }
              let(:email_double) { instance_double(VAProfile::Models::Email, email_address: 'test@example.com') }
              let(:home_phone_double) { instance_double(VAProfile::Models::Telephone, formatted_phone: '5035551234') }
              let(:mobile_phone_double) { instance_double(VAProfile::Models::Telephone, formatted_phone: '5035555678') }

              before do
                # Mock VAProfile contact info for both user and form profile usage
                # allow(VAProfileRedis::V2::ContactInformation).to receive(:for_user).with(user).and_return(
                #   contact_info_service
                # )
                allow(VAProfileRedis::V2::ContactInformation).to receive(:for_user).with(user).and_return(
                  contact_info_service
                )
                allow(contact_info_service).to receive_messages(email: email_double, home_phone: home_phone_double,
                                                                mobile_phone: mobile_phone_double)

                # Mock dependent service to avoid BGS calls
                allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
                allow(dependent_service).to receive(:get_dependents).and_return({ persons: [] })

                # Mock BID awards service
                allow_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_return(
                  OpenStruct.new(body: { 'awards_pension' => { 'is_in_receipt_of_pension' => false } })
                )
              end

              context 'with domestic address' do
                let(:domestic_address) do
                  build(:va_profile_address,
                        :mailing,
                        :domestic,
                        address_line1: '123 Main St',
                        address_line2: 'Apt 4B',
                        address_line3: 'Building C',
                        city: 'Portland',
                        state_code: 'OR',
                        zip_code: '97201',
                        country_code_iso3: 'USA')
                end

                it 'prefills address with zip_code when available' do
                  allow(contact_info_service).to receive(:mailing_address).and_return(domestic_address)

                  result = form_profile.prefill

                  expect(result[:form_data]).to have_key('veteranContactInformation')
                  vet_contact = result[:form_data]['veteranContactInformation']
                  expect(vet_contact).to have_key('veteranAddress')
                  vet_address = vet_contact['veteranAddress']
                  expect(vet_address['street']).to eq('123 Main St')
                  expect(vet_address['street2']).to eq('Apt 4B')
                  expect(vet_address['street3']).to eq('Building C')
                  expect(vet_address['city']).to eq('Portland')
                  expect(vet_address['state']).to eq('OR')
                  expect(vet_address['postalCode']).to eq('97201')
                  expect(vet_address['country']).to eq('USA')
                end
              end

              context 'with international address' do
                let(:international_address) do
                  build(:va_profile_address,
                        :mailing,
                        :international,
                        address_line1: '10 Downing Street',
                        city: 'London',
                        province: 'Greater London',
                        international_postal_code: 'SW1A 2AA',
                        country_code_iso3: 'GBR',
                        zip_code: nil,
                        state_code: nil)
                end

                it 'prefills address with international_postal_code when zip_code is nil' do
                  allow(contact_info_service).to receive(:mailing_address).and_return(international_address)

                  result = form_profile.prefill

                  expect(result[:form_data]).to have_key('veteranContactInformation')
                  vet_contact = result[:form_data]['veteranContactInformation']
                  expect(vet_contact).to have_key('veteranAddress')
                  vet_address = vet_contact['veteranAddress']
                  expect(vet_address['street']).to eq('10 Downing Street')
                  expect(vet_address['city']).to eq('London')
                  expect(vet_address['postalCode']).to eq('SW1A 2AA')
                  expect(vet_address['country']).to eq('GBR')
                  expect(vet_address['state']).to be_nil
                end
              end

              context 'when mailing address is blank' do
                it 'does not prefill address' do
                  allow(contact_info_service).to receive(:mailing_address).and_return(nil)

                  result = form_profile.prefill

                  expect(result[:form_data]).to have_key('veteranContactInformation')
                  # veteranContactInformation will have other fields but not veteranAddress
                  expect(result[:form_data]['veteranContactInformation']).not_to have_key('veteranAddress')
                end
              end
            end
          end
        end

        %w[
          21P-527EZ
          22-1990
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
          21-22
          21-22A
          21-2680
          FORM-MOCK-AE-DESIGN-PATTERNS
          FORM-MOCK-PREFILL
        ].each do |form_id|
          it "returns prefilled #{form_id}" do
            expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
            allow(Flipper).to receive(:enabled?).with(:pension_military_prefill, anything).and_return(false)
            VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                             allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
              expect_prefilled(form_id)
            end
          end
        end
      end

      context 'when Vet360 prefill is enabled' do
        let(:user) do
          build(:user, :loa3, :legacy_icn, suffix: 'Jr.', address: build(:va_profile_address),
                                           vet360_id: '1781151')
        end

        before do
          expect(user).to receive(:authorize).with(:lighthouse, :access_vet_status?).and_return(true)
          can_prefill_vaprofile(true)
          expect(user).to receive(:authorize).with(:va_profile, :access_to_v2?).and_return(true).at_least(:once)
          VAProfile::Configuration::SETTINGS.prefill = true # TODO: - is this missing in the failures above?
          expected_veteran_info = v21_526_ez_expected['veteran']
          expected_veteran_info['emailAddress'] = user.va_profile_email
          expected_veteran_info['primaryPhone'] = us_phone
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        end

        after do
          VAProfile::Configuration::SETTINGS.prefill = false
        end

        it 'returns prefilled 21-526EZ' do
          expect(user).to receive(:authorize).with(:lighthouse, :direct_deposit_access?)
                                             .and_return(true).at_least(:once)
          expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
          VCR.use_cassette('va_profile/v2/contact_information/get_address') do
            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              VCR.use_cassette('lighthouse/direct_deposit/show/200_valid_new_icn') do
                VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                                 allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
                  VCR.use_cassette('disability_max_ratings/max_ratings') do
                    expect_prefilled('21-526EZ')
                  end
                end
              end
            end
          end
        end
      end
    end

    context 'with a burial application form' do
      it 'returns the va profile mapped to the burial form' do
        expect_prefilled('21P-530EZ')
      end

      context 'without address' do
        let(:v21_p_530_ez_expected) do
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
          allow_any_instance_of(Burials::FormProfiles::VA21p530ez)
            .to receive(:initialize_contact_information).and_return(FormContactInformation.new)
        end

        it "doesn't throw an exception" do
          expect_prefilled('21P-530EZ')
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
        expect(errors.empty?).to be(true), "schema errors: #{errors}"
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
        non_prefill = prefill['nonPrefill']
        expect(non_prefill['veteranSsnLastFour']).to be_a String
        expect(non_prefill['veteranVaFileNumberLastFour']).to be_a String
      end

      it 'prefills an object that passes the schema' do
        full_example = JSON.parse Rails.root.join('spec', 'fixtures', 'notice_of_disagreements',
                                                  'valid_NOD_create_request.json').read

        test_data = full_example.deep_merge prefill.except('nonPrefill')
        errors = JSON::Validator.fully_validate(
          schema,
          test_data,
          validate_schema: true
        )
        expect(errors.empty?).to be(true), "schema errors: #{errors}"
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
  end

  describe 'loading 10-7959C form mappings' do
    it "doesn't raise an IOError" do
      expect { FormProfile.load_form_mapping('10-7959C') }.not_to raise_error
    end

    it 'loads the correct data' do
      mapping_file = Rails.root.join('config', 'form_profile_mappings', '10-7959C.yml')
      mappings = YAML.load_file(mapping_file)

      expect(FormProfile.load_form_mapping('10-7959C')).to match(mappings)
    end
  end

  describe '.load_form_mapping' do
    it 'handles uppercase form ID 40-1330M with lowercase filename' do
      expect { FormProfile.load_form_mapping('40-1330M') }.not_to raise_error
    end
  end
end
