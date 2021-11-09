# frozen_string_literal: true

FactoryBot.define do
  factory :hca_in_progress_form, class: 'InProgressForm' do
    user_uuid { SecureRandom.uuid }
    form_id { '1010cg' }
    metadata do
      {
        savedAt: 1_595_954_803_670,
        version: 6,
        returnUrl: '/form-url/review-and-submit'
      }
    end
    form_data do
      {
        isEssentialAcaCoverage: true,
        'view:preferredFacility': {
          'view:facilityState': 'AL',
          vaMedicalFacility: '520GA'
        },
        'view:locator': {
        },
        wantsInitialVaContact: true,
        isCoveredByHealthInsurance: true,
        providers: [
          {
            insuranceName: 'Big Insurance Co',
            insurancePolicyHolderName: 'Jim Doe',
            insurancePolicyNumber: '2342344',
            insuranceGroupCode: '2324234434'
          }
        ],
        isMedicaidEligible: true,
        isEnrolledMedicarePartA: true,
        medicarePartAEffectiveDate: '2009-01-02',
        deductibleMedicalExpenses: 234,
        deductibleFuneralExpenses: 11,
        deductibleEducationExpenses: 0,
        veteranGrossIncome: 3_242_434,
        veteranNetIncome: 23_424,
        veteranOtherIncome: 23_424,
        'view:spouseIncome': {
          spouseGrossIncome: 23_424,
          spouseNetIncome: 23_424,
          spouseOtherIncome: 23_424
        },
        dependents: [
          {
            fullName: {
              first: 'Ben',
              middle: 'Joe',
              last: 'Doe',
              suffix: 'Sr.'
            },
            dependentRelation: 'Son',
            socialSecurityNumber: '234666654',
            becameDependent: '2003-01-03',
            dateOfBirth: '2003-01-01',
            disabledBefore18: true,
            attendedSchoolLastYear: true,
            dependentEducationExpenses: 453,
            cohabitedLastYear: false,
            receivedSupportLastYear: true,
            grossIncome: 0,
            netIncome: 0,
            otherIncome: 0
          }
        ],
        'view:reportDependents': true,
        spouseFullName: {
          first: 'Jane',
          middle: 'Pam',
          last: 'Doe',
          suffix: 'II'
        },
        spouseSocialSecurityNumber: '232422344',
        spouseDateOfBirth: '1980-01-02',
        dateOfMarriage: '2004-01-02',
        cohabitedLastYear: false,
        provideSupportLastYear: true,
        sameAddress: false,
        'view:spouseContactInformation': {
          spouseAddress: {
            street: '123 maple st',
            street2: 'Apt 1',
            street3: 'Floor 2',
            city: 'Florence',
            country: 'USA',
            state: 'MA',
            postalCode: '01060'
          },
          spousePhone: '3424445555'
        },
        discloseFinancialInformation: true,
        vaCompensationType: 'highDisability',
        purpleHeartRecipient: true,
        isFormerPow: true,
        postNov111998Combat: true,
        disabledInLineOfDuty: true,
        swAsiaCombat: true,
        vietnamService: true,
        exposedToRadiation: true,
        radiumTreatments: true,
        campLejeune: true,
        lastServiceBranch: 'air force',
        lastEntryDate: '2000-01-02',
        lastDischargeDate: '2005-02-01',
        dischargeType: 'general',
        email: 'test@test.com',
        'view:emailConfirmation': 'test@test.com',
        homePhone: '5555555555',
        mobilePhone: '4444444444',
        veteranAddress: {
          street: '123 aspen st',
          street2: 'Apt 4',
          street3: 'Room 6',
          city: 'Hadley',
          country: 'USA',
          state: 'MA',
          postalCode: '01070'
        },
        gender: 'M',
        maritalStatus: 'Married',
        'view:demographicCategories': {
          isSpanishHispanicLatino: true,
          isAmericanIndianOrAlaskanNative: true,
          isBlackOrAfricanAmerican: true,
          isNativeHawaiianOrOtherPacificIslander: true,
          isAsian: true,
          isWhite: true
        },
        veteranDateOfBirth: '1980-03-02',
        veteranSocialSecurityNumber: '324234444',
        'view:placeOfBirth': {
          cityOfBirth: 'Boston',
          stateOfBirth: 'MA'
        },
        veteranFullName: {
          first: 'Jim',
          middle: 'Bob',
          last: 'Doe',
          suffix: 'Jr.'
        },
        mothersMaidenName: 'Smith',
        privacyAgreementAccepted: true,
        testUploadFile: {
          filePath: '/src/platform/testing/',
          fileName: 'example-upload.png',
          fileTypeSelection: '7'
        }
      }.to_json
    end
  end
end
