# frozen_string_literal: true

FactoryBot.define do
  factory :in_progress_form do
    user_uuid { SecureRandom.uuid }
    form_id { 'edu_benefits' }
    metadata {
      {
        version: 1,
        return_url: 'foo.com'
      }
    }
    form_data do
      {
        chapter1606: true,
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        gender: 'M',
        veteranDateOfBirth: '1985-03-07',
        veteranSocialSecurityNumber: '111223333',
        veteranAddress: {
          country: 'USA',
          state: 'WI',
          postalCode: '53130',
          street: '123 Main St',
          city: 'Milwaukee'
        },
        homePhone: '5551110000',
        secondaryContact: {
          fullName: 'Sibling Olson',
          sameAddress: true
        },
        bankAccount: {
          accountType: 'checking',
          bankName: 'First Bank of JSON',
          routingNumber: '123456789',
          accountNumber: '88888888888'
        },
        school: {
          name: 'FakeData University',
          address: {
            country: 'USA',
            state: 'MD',
            postalCode: '21231',
            street: '111 Uni Drive',
            city: 'Baltimore'
          },
          startDate: '2016-08-29',
          educationalObjective: '...'
        },
        educationType: 'college',
        postHighSchoolTrainings: [
          {
            name: 'OtherCollege Name',
            dateRange: {
              from: '1999-01-01',
              to: '2000-01-01'
            },
            city: 'New York',
            hours: 8,
            hoursType: 'semester',
            state: 'NY',
            degreeReceived: 'BA',
            major: 'History'
          }
        ],
        currentlyActiveDuty: {
          yes: false,
          onTerminalLeave: false,
          nonVaAssistance: false
        },
        highSchoolOrGedCompletionDate: '2010-06-06',
        additionalContributions: false,
        activeDutyKicker: false,
        reserveKicker: false,
        serviceBefore1977: {
          married: true,
          haveDependents: true,
          parentDependent: false
        },
        toursOfDuty: [
          {
            dateRange: {
              from: '2001-01-01',
              to: '2010-10-10'
            },
            serviceBranch: 'Army',
            serviceStatus: 'Active Duty',
            involuntarilyCalledToDuty: 'yes'
          },
          {
            dateRange: {
              from: '1995-01-01',
              to: '1998-10-10'
            },
            serviceBranch: 'Army',
            serviceStatus: 'Honorable Discharge',
            involuntarilyCalledToDuty: 'yes'
          }
        ],
        faaFlightCertificatesInformation: 'cert1, cert2',
        privacyAgreementAccepted: true
      }.to_json
    end

    factory :in_progress_update_form do
      form_data do
        {
          chapter1606: true,
          veteranFullName: {
            first: 'Mark',
            last: 'Olson'
          },
          gender: 'M',
          veteranDateOfBirth: '1985-03-07',
          veteranSocialSecurityNumber: '111223333',
          veteranAddress: {
            country: 'USA',
            state: 'CA',
            postalCode: '90210',
            street: 'Sunset Blvd',
            city: 'Beverly Hills'
          },
          homePhone: '3101112222',
          secondaryContact: {
            fullName: 'Sibling Olson',
            sameAddress: true
          },
          bankAccount: {
            accountType: 'checking',
            bankName: 'First Bank of JSON',
            routingNumber: '123456789',
            accountNumber: '88888888888'
          },
          school: {
            name: 'FakeData University',
            address: {
              country: 'USA',
              state: 'MD',
              postalCode: '21231',
              street: '111 Uni Drive',
              city: 'Baltimore'
            },
            startDate: '2016-08-29',
            educationalObjective: '...'
          },
          educationType: 'college',
          postHighSchoolTrainings: [
            {
              name: 'OtherCollege Name',
              dateRange: {
                from: '1999-01-01',
                to: '2000-01-01'
              },
              city: 'New York',
              hours: 8,
              hoursType: 'semester',
              state: 'NY',
              degreeReceived: 'BA',
              major: 'History'
            }
          ],
          currentlyActiveDuty: {
            yes: false,
            onTerminalLeave: false,
            nonVaAssistance: false
          },
          highSchoolOrGedCompletionDate: '2010-06-06',
          additionalContributions: false,
          activeDutyKicker: false,
          reserveKicker: false,
          serviceBefore1977: {
            married: true,
            haveDependents: true,
            parentDependent: false
          },
          toursOfDuty: [
            {
              dateRange: {
                from: '2001-01-01',
                to: '2010-10-10'
              },
              serviceBranch: 'Army',
              serviceStatus: 'Active Duty',
              involuntarilyCalledToDuty: 'yes'
            },
            {
              dateRange: {
                from: '1995-01-01',
                to: '1998-10-10'
              },
              serviceBranch: 'Army',
              serviceStatus: 'Honorable Discharge',
              involuntarilyCalledToDuty: 'yes'
            }
          ],
          faaFlightCertificatesInformation: 'cert1, cert2',
          privacyAgreementAccepted: true
        }.to_json
      end
    end

    factory :in_progress_526_form do
      user_uuid { SecureRandom.uuid }
      form_id { '21-526EZ' }
      metadata {
        {
          version: 1,
          return_url: 'foo.com'
        }
      }
      form_data do
        {
          'veteran' => {
            'phone_email_card' => {
              'primary_phone' => '7779998888',
              'email_address' => 'me@foo.com'
            },
            'mailing_address' => {
              'country' => 'USA',
              'address_line1' => '123 Main St.',
              'city' => 'Costa Mesa',
              'state' => 'CA',
              'zip_code' => '92626'
            },
            'view:contact_info_description' => {},
            'homelessness' => {}
          },
          'privacy_agreement_accepted' => false,
          'view:military_history_note' => {},
          'obligation_term_of_service_date_range' => {},
          'view:disabilities_clarification' => {},
          'standard_claim' => false,
          'view:fdc_warning' => {}
        }.to_json
      end
    end
    
    factory :hca_in_progress_form do
      user_uuid { SecureRandom.uuid }
      form_id { '1010cg' }
      metadata {
        {
          savedAt: 1595954803670,
          version: 6,
          return_url: "/form-url/review-and-submit"
        }
      }
      form_data do
        {
          "isEssentialAcaCoverage": true,
          "view:preferredFacility": {
            "view:facilityState": "AL",
            "vaMedicalFacility": "520GA"
          },
          "view:locator": {
          },
          "wantsInitialVaContact": true,
          "isCoveredByHealthInsurance": true,
          "providers": [
            {
              "insuranceName": "Big Insurance Co",
              "insurancePolicyHolderName": "Jim Doe",
              "insurancePolicyNumber": "2342344",
              "insuranceGroupCode": "2324234434"
            }
          ],
          "isMedicaidEligible": true,
          "isEnrolledMedicarePartA": true,
          "medicarePartAEffectiveDate": "2009-01-02",
          "deductibleMedicalExpenses": 234,
          "deductibleFuneralExpenses": 11,
          "deductibleEducationExpenses": 0,
          "veteranGrossIncome": 3242434,
          "veteranNetIncome": 23424,
          "veteranOtherIncome": 23424,
          "view:spouseIncome": {
            "spouseGrossIncome": 23424,
            "spouseNetIncome": 23424,
            "spouseOtherIncome": 23424
          },
          "dependents": [
            {
              "fullName": {
                "first": "Ben",
                "middle": "Joe",
                "last": "Doe",
                "suffix": "Sr."
              },
              "dependentRelation": "Son",
              "socialSecurityNumber": "234666654",
              "becameDependent": "2003-01-03",
              "dateOfBirth": "2003-01-01",
              "disabledBefore18": true,
              "attendedSchoolLastYear": true,
              "dependentEducationExpenses": 453,
              "cohabitedLastYear": false,
              "receivedSupportLastYear": true,
              "grossIncome": 0,
              "netIncome": 0,
              "otherIncome": 0
            }
          ],
          "view:reportDependents": true,
          "spouseFullName": {
            "first": "Jane",
            "middle": "Pam",
            "last": "Doe",
            "suffix": "II"
          },
          "spouseSocialSecurityNumber": "232422344",
          "spouseDateOfBirth": "1980-01-02",
          "dateOfMarriage": "2004-01-02",
          "cohabitedLastYear": false,
          "provideSupportLastYear": true,
          "sameAddress": false,
          "view:spouseContactInformation": {
            "spouseAddress": {
              "street": "123 maple st",
              "street2": "Apt 1",
              "street3": "Floor 2",
              "city": "Florence",
              "country": "USA",
              "state": "MA",
              "postalCode": "01060"
            },
            "spousePhone": "3424445555"
          },
          "discloseFinancialInformation": true,
          "vaCompensationType": "highDisability",
          "purpleHeartRecipient": true,
          "isFormerPow": true,
          "postNov111998Combat": true,
          "disabledInLineOfDuty": true,
          "swAsiaCombat": true,
          "vietnamService": true,
          "exposedToRadiation": true,
          "radiumTreatments": true,
          "campLejeune": true,
          "lastServiceBranch": "air force",
          "lastEntryDate": "2000-01-02",
          "lastDischargeDate": "2005-02-01",
          "dischargeType": "general",
          "email": "test@test.com",
          "view:emailConfirmation": "test@test.com",
          "homePhone": "5555555555",
          "mobilePhone": "4444444444",
          "veteranAddress": {
            "street": "123 aspen st",
            "street2": "Apt 4",
            "street3": "Room 6",
            "city": "Hadley",
            "country": "USA",
            "state": "MA",
            "postalCode": "01070"
          },
          "gender": "M",
          "maritalStatus": "Married",
          "view:demographicCategories": {
            "isSpanishHispanicLatino": true,
            "isAmericanIndianOrAlaskanNative": true,
            "isBlackOrAfricanAmerican": true,
            "isNativeHawaiianOrOtherPacificIslander": true,
            "isAsian": true,
            "isWhite": true
          },
          "veteranDateOfBirth": "1980-03-02",
          "veteranSocialSecurityNumber": "324234444",
          "view:placeOfBirth": {
            "cityOfBirth": "Boston",
            "stateOfBirth": "MA"
          },
          "veteranFullName": {
            "first": "Jim",
            "middle": "Bob",
            "last": "Doe",
            "suffix": "Jr."
          },
          "mothersMaidenName": "Smith",
          "privacyAgreementAccepted": true,
          "testUploadFile": {
            "filePath": "/src/platform/testing/",
            "fileName": "example-upload.png",
            "fileTypeSelection": "7"
          }
        }.to_json
      end
    end
  end
end
