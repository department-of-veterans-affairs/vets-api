# frozen_string_literal: true

module ClaimsApi
  module Forms
    class Form526ResponseSwagger
      include Swagger::Blocks
      EXAMPLE_PATH = ClaimsApi::Engine.root.join('app', 'swagger', 'claims_api', 'forms', 'form_526_example.json')

      swagger_component do
        schema :Form526Input do
          key :required, %i[type attributes]
          key :description, '526 Claim Form submission with minimum required for auto establishment. Note - Until a claim is established in VA systems, values may show null'

          property :data do
            key :type, :object
            key :example, JSON.parse(File.read(EXAMPLE_PATH))
            property :type do
              key :type, :string
              key :example, 'form/526'
              key :description, 'Required by JSON API standard'
            end

            property :attributes do
              key :type, :object
              key :description, 'Required by JSON API standard'
              req = %i[veteran serviceInformation disabilities claimantCertification standardClaim applicationExpirationDate]
              key :required, req

              property :veteran do
                key :type, :object
                key :description, 'Veteran Object being submitted in Claim'
                key :required, %i[currentlyVAEmployee currentMailingAddress]

                property :currentlyVAEmployee do
                  key :type, :boolean
                  key :example, false
                  key :description, 'Flag if Veteran is VA Employee'
                end

                property :currentMailingAddress do
                  key :type, :object
                  key :description, 'Current Mailing Address Object being submitted'
                  key :required, %i[
                    addressLine1
                    city
                    state
                    country
                    zipFirstFive
                    type
                  ]

                  property :addressLine1 do
                    key :type, :string
                    key :example, '1234 Couch Street'
                    key :description, 'Address Veteran resides in'
                  end

                  property :addressLine2 do
                    key :type, :string
                    key :example, 'Apt. 22'
                    key :description, 'Additional Address Information Veteran resides in'
                  end

                  property :city do
                    key :type, :string
                    key :example, 'Portland'
                    key :description, 'City Veteran resides in'
                  end

                  property :country do
                    key :type, :string
                    key :example, 'USA'
                    key :description, 'Country Veteran resides in'
                  end

                  property :zipFirstFive do
                    key :type, :string
                    key :example, '12345'
                    key :description, 'Zipcode (First 5 digits) Veteran resides in'
                  end

                  property :zipLastFour do
                    key :type, :string
                    key :example, '6789'
                    key :description, 'Zipcode (Last 4 digits) Veteran resides in'
                  end

                  property :type do
                    key :type, :string
                    key :example, 'DOMESTIC'
                    key :description, 'Type of residence Veteran resides in'
                  end

                  property :state do
                    key :type, :string
                    key :example, 'OR'
                    key :description, 'State Veteran resides in'
                  end
                end

                property :changeOfAddress do
                  key :type, :object
                  key :description, 'A Change of Address Object being submitted'

                  property :beginningDate do
                    key :type, :string
                    key :format, 'date'
                    key :example, '2018-06-04'
                    key :description, 'Date in YYYY-MM-DD the Veteran changed address'
                  end

                  property :addressChangeType do
                    key :type, :string
                    key :example, 'PERMANENT'
                    key :description, 'Temporary or Permanent change of address'
                  end

                  property :addressLine1 do
                    key :type, :string
                    key :example, '1234 Couch Stree'
                    key :description, 'New Address Veteran resides in'
                  end

                  property :addressLine2 do
                    key :type, :string
                    key :example, 'Apt. 22'
                    key :description, 'New Additional Address Information Veteran resides in'
                  end

                  property :city do
                    key :type, :string
                    key :example, 'Portland'
                    key :description, 'New City Veteran resides in'
                  end

                  property :country do
                    key :type, :string
                    key :example, 'USA'
                    key :description, 'New Country Veteran resides in'
                  end

                  property :zipFirstFive do
                    key :type, :string
                    key :example, '12345'
                    key :description, 'New Zipcode (First 5 digits) Veteran resides in'
                  end

                  property :zipLastFour do
                    key :type, :string
                    key :example, '6789'
                    key :description, 'New Zipcode (Last 4 digits) Veteran resides in'
                  end

                  property :type do
                    key :type, :string
                    key :example, 'DOMESTIC'
                    key :description, 'New Type of residence Veteran resides in'
                  end

                  property :state do
                    key :type, :string
                    key :example, 'OR'
                    key :description, 'New State Veteran resides in'
                  end
                end

                property :homelessness do
                  key :type, :object
                  key :description, 'Object describing Veteran Homelessness if applicable'

                  property :pointOfContact do
                    key :type, :object
                    key :description, 'Object describing Homeless Veteran Point of Contact'

                    property :pointOfContactName do
                      key :type, :string
                      key :example, 'Jane Doe'
                      key :description, 'Point of contact in direct contact with Veteran'
                    end

                    property :primaryPhone do
                      key :type, :object
                      key :description, 'Phone Number Object for Point of Contact'

                      property :areaCode do
                        key :type, :string
                        key :example, '123'
                        key :description, 'Area code of Point of Contact'
                      end

                      property :phoneNumber do
                        key :type, :string
                        key :example, '1231234'
                        key :description, 'Primary phone of Point of Contact'
                      end
                    end
                  end

                  property :currentlyHomeless do
                    key :type, :object
                    key :description, ''
                    key :required, []

                    property :homelessSituationType do
                      key :type, :string
                      key :example, 'fleeing'
                      key :description, 'Current state of the veteran\'s homelessness'
                      key :enum, %w[
                        fleeing
                        shelter
                        notShelter
                        anotherPerson
                        other
                      ]
                    end

                    property :otherLivingSituation do
                      key :type, :string
                      key :example, 'other living situation'
                      key :description, 'List any other living scenarios'
                    end
                  end
                end

                property :flashes do
                  key :type, :array
                  key :description, 'Attributes that describe special circumstances which apply to a Veteran.'

                  items do
                    key :type, :string
                    key :example, 'Hardship'
                    key :enum, [
                      '1151 P&T',
                      '38 USC 1151',
                      'Active Chapter 31 Case',
                      'Agent Orange - Vietnam',
                      'Amyotrophic Lateral Sclerosis',
                      'Annual IU Eligibility Review-Fraud',
                      'Attorney Fee',
                      'Authzn to Release Information to Third Party',
                      'Automobile Adaptive Equipment Paid',
                      'Automobile Allowance Paid',
                      'BVA Decision',
                      'Blind',
                      'Blue Water Navy',
                      'C-123',
                      'CADD - Written Requests Only',
                      'CAVC Temp File',
                      'CH31 SAM',
                      'CHAMPUS Entitlement Exists',
                      'CRSC/CRDP Case',
                      'CSRS',
                      'CWA Exposure OIF/OND',
                      'Case Managed Development',
                      'Clear and Unmistakable Error',
                      'Closed Chapter 31 Case',
                      'Committee on Waiver Case',
                      'Compensation Award Line',
                      'Compensation Under 1925 Rating Schedule',
                      'Congressional',
                      'Converted - Automobile Adaptive Equipment Paid',
                      'Converted - Automobile Allowance Paid',
                      'Converted - Blind',
                      'Converted - Comp Under 1925 Rating Schedule',
                      'Converted - Created Combined Evaluation For 1996',
                      'Converted - Created Combined Evaluation For 1997',
                      'Converted - Created Combined Evaluation For 1998',
                      'Converted - Created Combined Evaluation For 1999',
                      'Converted - Created Combined Evaluation For 2000',
                      'Converted - Created Combined Evaluation For 2001',
                      'Converted - Created Combined Evaluation For 2002',
                      'Converted - Created Combined Evaluation For 2003',
                      'Converted - Created Combined Evaluation For 2004',
                      'Converted - Created Combined Evaluation For 2005',
                      'Converted - Created Combined Evaluation For 2006',
                      'Converted - Created Combined Evaluation For 2007',
                      'Converted - Created Combined Evaluation For 2008',
                      'Converted - Created Combined Evaluation For 2009',
                      'Converted - Created Combined Evaluation Not RBA',
                      'Converted - Created Combined Evaluation Pre 1996',
                      'Converted - Default Fiduciary Used',
                      'Converted - Disappearance of Veteran',
                      'Converted - File NBR Match & SSN/File NBR Mismatch',
                      'Converted - Folder Stored At RMC',
                      'Converted - Forfeiture Case',
                      'Converted - General Law Case',
                      'Converted - Gulf War Registry',
                      'Converted - In Receipt of Chapter 31',
                      'Converted - Marker/Engraving Paid',
                      'Converted - More Than 9 Children Existed',
                      'Converted - NSC Burial Paid',
                      'Converted - NSC Burial/Plot Paid',
                      'Converted - NSC Burial/Trans Paid',
                      'Converted - NSC Burial/Trans/Plot Paid',
                      'Converted - Naval Pension Case',
                      'Converted - P&T Decision Possibly Derived',
                      'Converted - POW',
                      'Converted - Plot Paid',
                      'Converted - Possible CHAMPVA Entitlement Exists',
                      'Converted - Potential Attorney Fee',
                      'Converted - Provider Proof of Medical Expense Case',
                      'Converted - Review SSN - Adjustments Made',
                      'Converted - SC Burial Paid',
                      'Converted - SC Burial/Plot Paid',
                      'Converted - SC Burial/Trans Paid',
                      'Converted - SSN Existed In Another Record',
                      'Converted - Severance Offset PCT Not Set',
                      'Converted - Severance Withhold Offset PCT Set',
                      'Converted - Special Adapted Housing Paid',
                      'Converted - Special Condition Existed',
                      'Converted - Spouse Matched Different SSN & NM/DOB',
                      'Converted - Spouse Matched NM/DOB But Not SSN',
                      'Converted - Spouse Matched NM/DOB- Overlaid SSN',
                      'Converted - Tort Offset PCT Not Set',
                      'Converted - Tort Withhold Offset PCT Set',
                      'Converted - Transportation Paid',
                      'Converted - Under IVM Review',
                      'Converted Retired Pay Involved',
                      'Copy VAF 21-526 before return to vet for sign',
                      'Counsel Folder Location',
                      'DBQ Referral Program',
                      'Death in Service',
                      'Denied - Fraud',
                      'Dependency Review - DOMA',
                      'Disappearance of Veteran',
                      'Disaster Impacted',
                      'Document(s) exist in VBMS',
                      'Documents Exist in Virtual VA',
                      'Dual Benefits',
                      'EHRM Pilot',
                      'Emergency Care',
                      'FBI Case',
                      'Filipino Equity Comp 15000',
                      'Filipino Equity Comp 9000',
                      'Finance Flash',
                      'Foreign Claim',
                      'Forfeiture Case',
                      'Formerly Homeless',
                      'Fugitive Felon',
                      'GW Undiagnosed Illness',
                      'Gulf War Registry',
                      'Hardship',
                      'Homeless',
                      'IDES Participant',
                      'If orig CFile found conduct Phase II Nehmer Review',
                      'In Receipt of Chapter 31',
                      'Incarceration',
                      'Incompetency',
                      'Insurance Overpayment',
                      'Job Training Folder Exists',
                      'Litigation Hold',
                      'Locked File',
                      'Lump Sum Retirement',
                      'Medal of Honor',
                      'Mini-VSC Orlando',
                      'Mini-VSC WPB',
                      'National Guard',
                      'Nehmer - AL Amyloidosis',
                      'Nehmer - IHD - PD - HCL',
                      'No Paper Claim Folder',
                      'No Paper NOD Folder',
                      'Non - Nehmer Agent Orange 2010',
                      'OIG Case',
                      'OWCP referral after rating, disallow, notify Vet',
                      'Office of Investigation, Central Office',
                      'POW',
                      'Pension Award Line',
                      'Philippine Service',
                      'Physical Claims File Exists',
                      'Potential Attorney Fee',
                      'Potential Incident',
                      'Priority Processing - Veteran over age 85',
                      'Private Attorney - Fees Payable',
                      'Private Attorney - No Fees Payable',
                      'Provider Proof of Medical Expense Case',
                      'Purple Heart',
                      'RAMP Participant - VSO',
                      'RECA Claims Pending',
                      'RECA Payments Made',
                      'Railroad Retirement',
                      'Rebuilt Fldr, Ntfy NPRC when consolid w/lost File',
                      'Recommend Rating Ready',
                      'Reserve',
                      'Restricted Access',
                      'Retro Funds W/H for Potential Incompetent Bene',
                      'Returned to Active Duty',
                      'Secret Service Case',
                      'Sensitive Level 6',
                      'Seriously Injured/Very Seriously Injured',
                      'Specially Adapted Housing Claimed',
                      'Supervised Direct Pay',
                      'TBI Equitable Relief Review',
                      'Temporary Folder Exists',
                      'Terminally Ill',
                      'Terminated - Fraud',
                      'Third Party Release',
                      'VA Employee',
                      'VACO Deferral Review',
                      'VACO Special Status 1',
                      'VACO Special Status 2',
                      'VBMS',
                      'VOW - VEI',
                      'VR Trainee',
                      'Vietnam In - Country Service Verified',
                      'Voluntary Separation Incentive'
                    ]
                  end
                end
              end

              property :serviceInformation do
                key :required, [:servicePeriods]
                key :type, :object
                key :description, 'Overview of Veteran\'s service history'

                property :servicePeriods do
                  key :type, :array
                  key :description, 'Identifies the Service dates and Branch the Veteran served in.'
                  items do
                    key :type, :object
                    key :required, %i[
                      serviceBranch
                      activeDutyBeginDate
                      activeDutyEndDate
                    ]

                    property :serviceBranch do
                      key :type, :string
                      key :example, 'Air Force'
                      key :description, 'Branch of Service during period'
                      key :enum, [
                        'Air Force',
                        'Air Force Reserve',
                        'Army',
                        'Army Reserve',
                        'Coast Guard',
                        'Coast Guard Reserve',
                        'Marine Corps',
                        'Marine Corps Reserve',
                        'Navy',
                        'Navy Reserve',
                        'NOAA'
                      ]
                    end

                    property :activeDutyBeginDate do
                      key :type, :string
                      key :format, :date
                      key :example, '1980-02-05'
                      key :description, 'Date Started Active Duty'
                    end

                    property :activeDutyEndDate do
                      key :type, :string
                      key :format, :date
                      key :example, '1990-01-02'
                      key :description, 'Date Completed Active Duty'
                    end
                  end
                end

                property :confinements do
                  key :type, :array
                  key :description, 'Identifies if the Veteran was confined or imprisoned at any point'
                  items do
                    key :type, :object

                    property :confinementBeginDate do
                      key :type, :string
                      key :format, :date
                      key :example, '1987-02-01'
                      key :description, 'Date Began Confinement'
                    end

                    property :confinementEndDate do
                      key :type, :string
                      key :format, :date
                      key :example, '1987-02-01'
                      key :description, 'Date Ended Confinement'
                    end
                  end
                end

                property :reservesNationalGuardService do
                  key :type, :object
                  key :description, 'Overview of Veteran\'s Reserve History'

                  property :title10Activation do
                    key :type, :object
                    key :description, 'Dates of when Reserve Veteran was Activated'

                    property :anticipatedSeparationDate do
                      key :type, :string
                      key :format, 'date'
                      key :example, '2020-01-01'
                      key :description, 'Date Seperation will occur'
                    end

                    property :title10ActivationDate do
                      key :type, :string
                      key :input, 'date'
                      key :example, '1999-03-04'
                      key :description, 'Date Title 10 Activates'
                    end
                  end

                  property :obligationTermOfServiceFromDate do
                    key :type, :string
                    key :input, 'date'
                    key :example, '2000-01-04'
                    key :description, 'Date Service Obligation Began'
                  end

                  property :obligationTermOfServiceToDate do
                    key :type, :string
                    key :input, 'date'
                    key :example, '2004-01-04'
                    key :description, 'Date Service Obligation Ended'
                  end

                  property :unitName do
                    key :type, :string
                    key :example, 'Seal Team Six'
                    key :description, 'Official Unit Designation'
                  end

                  property :unitPhone do
                    key :type, :object
                    key :description, 'Phone number Object for Veteran\'s old unit'

                    property :areaCode do
                      key :type, :string
                      key :example, '123'
                      key :description, 'Area code of Unit'
                    end

                    property :phoneNumber do
                      key :type, :string
                      key :example, '1231234'
                      key :description, 'Primary phone of Unit'
                    end
                  end

                  property :receivingInactiveDutyTrainingPay do
                    key :type, :boolean
                    key :example, true
                    key :description, 'Do they receive Inactive Duty Training Pay'
                  end
                end

                property :alternateNames do
                  key :type, :array
                  key :description, 'Names Veteran has legally used in the past'
                  items do
                    key :type, :object

                    property :firstName do
                      key :type, :string
                      key :example, 'Jack'
                      key :description, 'Alternate First Name'
                    end

                    property :middleName do
                      key :type, :string
                      key :example, 'Clint'
                      key :description, 'Alternate Middle Name'
                    end

                    property :lastName do
                      key :type, :string
                      key :example, 'Bauer'
                      key :description, 'Alternate Last Name'
                    end
                  end
                end
              end

              property :disabilities do
                key :type, :array
                key :description, 'Identifies the Service Disability information of the Veteran'

                items do
                  key :type, :object
                  key :required, %i[
                    name
                    disabilityActionType
                  ]

                  property :ratedDisabilityId do
                    key :type, :string
                    key :description, 'The Type of Disability'
                    key :example, '1100583'
                  end

                  property :diagnosticCode do
                    key :type, :integer
                    key :description, 'Specific Diagnostic Code'
                    key :example, 9999
                  end

                  property :disabilityActionType do
                    key :type, :string
                    key :description, 'The status of the current disability.'
                    key :example, 'NEW'
                  end

                  property :name do
                    key :type, :string
                    key :description, 'What the Disability is called.'
                    key :example, 'PTSD (post traumatic stress disorder)'
                  end

                  property :specialIssues do
                    key :type, :array
                    key :description, 'The special issues related to the disability'

                    items do
                      key :type, :string
                      key :example, 'ALS'
                      key :enum, ['ALS',
                                  'HEPC',
                                  'POW',
                                  'PTSD/1',
                                  'PTSD/2',
                                  'PTSD/3',
                                  'PTSD/4',
                                  'MST',
                                  '38 USC 1151',
                                  'ABA Election',
                                  'Abandoned VDC Claim',
                                  'AMC NOD Brokering Project',
                                  'Administrative Decision Review - Level 1',
                                  'Administrative Decision Review - Level 2',
                                  'Agent Orange - Vietnam',
                                  'Agent Orange - outside Vietnam or unknown',
                                  'AMA SOC/SSOC Opt-In',
                                  'Amyotrophic Lateral Sclerosis (ALS)',
                                  'Annual Eligibility Report',
                                  'Asbestos',
                                  'AutoEstablish',
                                  'Automated Drill Pay Adjustment',
                                  'Automated Return to Active Duty',
                                  'BDD – Excluded',
                                  'Brokered - D1BC',
                                  'Brokered - Internal',
                                  'Burn Pit Exposure',
                                  'C-123',
                                  'COWC',
                                  'Character of Discharge',
                                  'Challenge',
                                  'ChemBio',
                                  'Claimant Service Verification Accepted',
                                  'Combat Related Death',
                                  'Compensation Service Review – AO Outside RVN & Ship',
                                  'Compensation Service Review - Equitable Relief',
                                  'Compensation Service Review - Extraschedular',
                                  'Compensation Service Review – MG/CBRNE/Shad',
                                  'Compensation Service Review - Opinion',
                                  'Compensation Service Review - Over $25K',
                                  'Compensation Service Review - POW',
                                  'Compensation Service Review - Radiation',
                                  'Decision Ready Claim',
                                  'Decision Ready Claim - Deferred',
                                  'Decision Ready Claim - Partial Deferred',
                                  'Disability Benefits Questionnaire - Private',
                                  'Disability Benefits Questionnaire - VA',
                                  'DRC – Exam Review Complete Approved',
                                  'DRC – Exam Review Complete Disapproved',
                                  'DRC – Pending File Scan',
                                  'DRC – Vendor Exam Recommendation',
                                  'DTA Error – Exam/MO',
                                  'DTA Error – Fed Recs',
                                  'DTA Error – Other Recs',
                                  'DTA Error – PMRs',
                                  'Emergency Care – CH17 Determination',
                                  'Enhanced Disability Severance Pay',
                                  'Environmental Hazard - Camp Lejeune',
                                  'Environmental Hazard – Camp Lejeune – Louisville',
                                  'Environmental Hazard in Gulf War',
                                  'Extra-Schedular 3.321(b)(1)',
                                  'Extra-Schedular IU 4.16(b)',
                                  'FDC Excluded - Additional Claim Submitted',
                                  'FDC Excluded - All Required Items Not Submitted',
                                  'FDC Excluded - Appeal Pending',
                                  'FDC Excluded - Appeal submitted',
                                  'FDC Excluded - Claim Pending',
                                  'FDC Excluded - Claimant Declined FDC Processing',
                                  'FDC Excluded - Evidence Received After FDC CEST',
                                  'FDC Excluded - FDC Certification Incomplete',
                                  'FDC Excluded - FTR to Examination',
                                  'FDC Excluded - Necessary Form(s) not Submitted',
                                  'FDC Excluded - Needs Non-Fed Evidence Development',
                                  'FDC Excluded - requires INDPT VRFCTN of FTI',
                                  'Fed Record Delay - No Further Dev',
                                  'Force Majeure',
                                  'Fully Developed Claim',
                                  'Gulf War Presumptive',
                                  'HIV',
                                  'Hepatitis C',
                                  'Hospital Adjustment Action Plan FY 18/19',
                                  'IDES Deferral',
                                  'JSRRC Request',
                                  'Local Hearing',
                                  'Local Mentor Review',
                                  'Local Quality Review',
                                  'Local Quality Review IPR',
                                  'Medical Foster Home',
                                  'Military Sexual Trauma (MST)',
                                  'MQAS Separation and Severance Pay Audit',
                                  'Mustard Gas',
                                  'National Quality Review',
                                  'Nehmer AO Peripheral Neuropathy',
                                  'Nehmer Phase II',
                                  'Non-ADL Notification Letter',
                                  'Non-Nehmer AO Peripheral Neuropathy',
                                  'Non-PTSD Personal Trauma',
                                  'Potential Under/Overpayment',
                                  'POW',
                                  'PTSD - Combat',
                                  'PTSD - Non-Combat',
                                  'PTSD - Personal Trauma',
                                  'RO Special issue 1',
                                  'RO Special issue 2',
                                  'RO Special Issue 3',
                                  'RO Special Issue 4',
                                  'RO Special Issue 5',
                                  'RO Special Issue 6',
                                  'RO Special Issue 7',
                                  'RO Special Issue 8',
                                  'RO Special Issue 9',
                                  'RVSR Examination',
                                  'Radiation',
                                  'Radiation Radiogenic Disability Confirmed',
                                  'Rating Decision Review - Level 1',
                                  'Rating Decision Review - Level 2',
                                  'Ready for Exam',
                                  'Same Station Review',
                                  'SHAD',
                                  'Sarcoidosis',
                                  'Simultaneous Award Adjustment Not Permitted',
                                  'Specialized Records Request',
                                  'Stage 1 Development',
                                  'Stage 2 Development',
                                  'Stage 3 Development',
                                  'TBI Exam Review',
                                  'Temp 100 Convalescence',
                                  'Temp 100 Hospitalization',
                                  'Tobacco',
                                  'Tort Claim',
                                  'Traumatic Brain Injury',
                                  'Upfront Verification',
                                  'VACO Special issue 1',
                                  'VACO Special issue 2',
                                  'VACO Special Issue 3',
                                  'VACO Special Issue 4',
                                  'VACO Special Issue 5',
                                  'VACO Special Issue 6',
                                  'VACO Special Issue 7',
                                  'VACO Special Issue 8',
                                  'VACO Special Issue 9',
                                  'VASRD-Cardiovascular',
                                  'VASRD-Dental',
                                  'VASRD-Digestive',
                                  'VASRD-Endocrine',
                                  'VASRD-Eye',
                                  'VASRD-GU',
                                  'VASRD-GYN',
                                  'VASRD-Hemic',
                                  'VASRD-Infectious',
                                  'VASRD-Mental',
                                  'VASRD-Musculoskeletal',
                                  'VASRD-Neurological',
                                  'VASRD-Respiratory/Auditory',
                                  'VASRD-Skin',
                                  'Vendor Exclusion - No Diagnosis',
                                  'VONAPP Direct Connect',
                                  'WARTAC',
                                  'WARTAC Trainee']
                    end
                  end

                  property :secondaryDisabilities do
                    key :type, :array
                    key :description, 'Identifies the Secondary Service Disability information of the Veteran'

                    items do
                      key :type, :object
                      key :required, %i[
                        name
                        disabilityActionType
                        serviceRelevance
                      ]

                      property :name do
                        key :type, :string
                        key :description, 'What the Disability is called.'
                        key :example, 'PTSD personal trauma'
                      end

                      property :disabilityActionType do
                        key :type, :string
                        key :description, 'The status of the secondary disability.'
                        key :example, 'SECONDARY'
                      end

                      property :serviceRelevance do
                        key :type, :string
                        key :description, 'How the veteran got the disability.'
                        key :example, 'Caused by a service-connected disability\\nLengthy description'
                      end

                      property :specialIssues do
                        key :type, :array
                        key :description, 'The special issues related to the disability'

                        items do
                          key :type, :string
                          key :example, 'ALS'
                          key :enum, ['ALS',
                                      'HEPC',
                                      'POW',
                                      'PTSD/1',
                                      'PTSD/2',
                                      'PTSD/3',
                                      'PTSD/4',
                                      'MST',
                                      '38 USC 1151',
                                      'ABA Election',
                                      'Abandoned VDC Claim',
                                      'AMC NOD Brokering Project',
                                      'Administrative Decision Review - Level 1',
                                      'Administrative Decision Review - Level 2',
                                      'Agent Orange - Vietnam',
                                      'Agent Orange - outside Vietnam or unknown',
                                      'AMA SOC/SSOC Opt-In',
                                      'Amyotrophic Lateral Sclerosis (ALS)',
                                      'Annual Eligibility Report',
                                      'Asbestos',
                                      'AutoEstablish',
                                      'Automated Drill Pay Adjustment',
                                      'Automated Return to Active Duty',
                                      'BDD – Excluded',
                                      'Brokered - D1BC',
                                      'Brokered - Internal',
                                      'Burn Pit Exposure',
                                      'C-123',
                                      'COWC',
                                      'Character of Discharge',
                                      'Challenge',
                                      'ChemBio',
                                      'Claimant Service Verification Accepted',
                                      'Combat Related Death',
                                      'Compensation Service Review – AO Outside RVN & Ship',
                                      'Compensation Service Review - Equitable Relief',
                                      'Compensation Service Review - Extraschedular',
                                      'Compensation Service Review – MG/CBRNE/Shad',
                                      'Compensation Service Review - Opinion',
                                      'Compensation Service Review - Over $25K',
                                      'Compensation Service Review - POW',
                                      'Compensation Service Review - Radiation',
                                      'Decision Ready Claim',
                                      'Decision Ready Claim - Deferred',
                                      'Decision Ready Claim - Partial Deferred',
                                      'Disability Benefits Questionnaire - Private',
                                      'Disability Benefits Questionnaire - VA',
                                      'DRC – Exam Review Complete Approved',
                                      'DRC – Exam Review Complete Disapproved',
                                      'DRC – Pending File Scan',
                                      'DRC – Vendor Exam Recommendation',
                                      'DTA Error – Exam/MO',
                                      'DTA Error – Fed Recs',
                                      'DTA Error – Other Recs',
                                      'DTA Error – PMRs',
                                      'Emergency Care – CH17 Determination',
                                      'Enhanced Disability Severance Pay',
                                      'Environmental Hazard - Camp Lejeune',
                                      'Environmental Hazard – Camp Lejeune – Louisville',
                                      'Environmental Hazard in Gulf War',
                                      'Extra-Schedular 3.321(b)(1)',
                                      'Extra-Schedular IU 4.16(b)',
                                      'FDC Excluded - Additional Claim Submitted',
                                      'FDC Excluded - All Required Items Not Submitted',
                                      'FDC Excluded - Appeal Pending',
                                      'FDC Excluded - Appeal submitted',
                                      'FDC Excluded - Claim Pending',
                                      'FDC Excluded - Claimant Declined FDC Processing',
                                      'FDC Excluded - Evidence Received After FDC CEST',
                                      'FDC Excluded - FDC Certification Incomplete',
                                      'FDC Excluded - FTR to Examination',
                                      'FDC Excluded - Necessary Form(s) not Submitted',
                                      'FDC Excluded - Needs Non-Fed Evidence Development',
                                      'FDC Excluded - requires INDPT VRFCTN of FTI',
                                      'Fed Record Delay - No Further Dev',
                                      'Force Majeure',
                                      'Fully Developed Claim',
                                      'Gulf War Presumptive',
                                      'HIV',
                                      'Hepatitis C',
                                      'Hospital Adjustment Action Plan FY 18/19',
                                      'IDES Deferral',
                                      'JSRRC Request',
                                      'Local Hearing',
                                      'Local Mentor Review',
                                      'Local Quality Review',
                                      'Local Quality Review IPR',
                                      'Medical Foster Home',
                                      'Military Sexual Trauma (MST)',
                                      'MQAS Separation and Severance Pay Audit',
                                      'Mustard Gas',
                                      'National Quality Review',
                                      'Nehmer AO Peripheral Neuropathy',
                                      'Nehmer Phase II',
                                      'Non-ADL Notification Letter',
                                      'Non-Nehmer AO Peripheral Neuropathy',
                                      'Non-PTSD Personal Trauma',
                                      'Potential Under/Overpayment',
                                      'POW',
                                      'PTSD - Combat',
                                      'PTSD - Non-Combat',
                                      'PTSD - Personal Trauma',
                                      'RO Special issue 1',
                                      'RO Special issue 2',
                                      'RO Special Issue 3',
                                      'RO Special Issue 4',
                                      'RO Special Issue 5',
                                      'RO Special Issue 6',
                                      'RO Special Issue 7',
                                      'RO Special Issue 8',
                                      'RO Special Issue 9',
                                      'RVSR Examination',
                                      'Radiation',
                                      'Radiation Radiogenic Disability Confirmed',
                                      'Rating Decision Review - Level 1',
                                      'Rating Decision Review - Level 2',
                                      'Ready for Exam',
                                      'Same Station Review',
                                      'SHAD',
                                      'Sarcoidosis',
                                      'Simultaneous Award Adjustment Not Permitted',
                                      'Specialized Records Request',
                                      'Stage 1 Development',
                                      'Stage 2 Development',
                                      'Stage 3 Development',
                                      'TBI Exam Review',
                                      'Temp 100 Convalescence',
                                      'Temp 100 Hospitalization',
                                      'Tobacco',
                                      'Tort Claim',
                                      'Traumatic Brain Injury',
                                      'Upfront Verification',
                                      'VACO Special issue 1',
                                      'VACO Special issue 2',
                                      'VACO Special Issue 3',
                                      'VACO Special Issue 4',
                                      'VACO Special Issue 5',
                                      'VACO Special Issue 6',
                                      'VACO Special Issue 7',
                                      'VACO Special Issue 8',
                                      'VACO Special Issue 9',
                                      'VASRD-Cardiovascular',
                                      'VASRD-Dental',
                                      'VASRD-Digestive',
                                      'VASRD-Endocrine',
                                      'VASRD-Eye',
                                      'VASRD-GU',
                                      'VASRD-GYN',
                                      'VASRD-Hemic',
                                      'VASRD-Infectious',
                                      'VASRD-Mental',
                                      'VASRD-Musculoskeletal',
                                      'VASRD-Neurological',
                                      'VASRD-Respiratory/Auditory',
                                      'VASRD-Skin',
                                      'Vendor Exclusion - No Diagnosis',
                                      'VONAPP Direct Connect',
                                      'WARTAC',
                                      'WARTAC Trainee']
                        end
                      end
                    end
                  end
                end
              end

              property :treatments do
                key :type, :array
                key :description, 'Identifies the Service Treatment information of the Veteran'

                items do
                  key :type, :object

                  property :startDate do
                    key :type, :date
                    key :description, 'Date Veteran started treatment'
                    key :example, '2018-03-02'
                  end

                  property :endDate do
                    key :type, :date
                    key :description, 'Date Veteran ended treatment'
                    key :example, '2018-03-03'
                  end

                  property :treatedDisabilityNames do
                    key :type, :array
                    key :description, 'Identifies the Service Treatment nomenclature of the Veteran'

                    items do
                      key :type, :string
                      key :description, 'Name of Disabilities Veteran was Treated for'
                      key :example, 'PTSD (post traumatic stress disorder)'
                    end
                  end

                  property :center do
                    key :type, :object
                    key :description, 'Location of Veteran Treatment'

                    property :name do
                      key :type, :string
                      key :description, 'Name of facility Veteran was treated in'
                      key :example, 'Private Facility 2'
                    end

                    property :country do
                      key :type, :string
                      key :description, 'Country Veteran was treated in'
                      key :example, 'USA'
                    end
                  end
                end
              end

              property :servicePay do
                key :type, :object
                key :description, 'Details about Veteran receiving Service Pay from DoD'

                property :waiveVABenefitsToRetainTrainingPay do
                  key :type, :boolean
                  key :description, 'Is Veteran Waiving benefits to retain training pay'
                  key :example, true
                end

                property :waiveVABenefitsToRetainRetiredPay do
                  key :type, :boolean
                  key :description, 'Is Veteran Waiving benefits to retain Retiree pay'
                  key :example, true
                end

                property :militaryRetiredPay do
                  key :type, :object
                  key :description, 'Retirement Pay information from Military Service'

                  property :receiving do
                    key :type, :boolean
                    key :description, 'Is Veteran getting Retiree pay'
                    key :example, true
                  end

                  property :payment do
                    key :type, :object
                    key :description, 'Part of DoD paying Retirement Benefits'

                    property :serviceBranch do
                      key :type, :string
                      key :description, 'Branch of Service making payments'
                      key :example, 'Air Force'
                      key :enum, [
                        'Air Force',
                        'Air Force Reserve',
                        'Army',
                        'Army Reserve',
                        'Coast Guard',
                        'Coast Guard Reserve',
                        'Marine Corps',
                        'Marine Corps Reserve',
                        'Navy',
                        'Navy Reserve',
                        'NOAA'
                      ]
                    end
                  end
                end
              end

              property :directDeposit do
                key :type, :object
                key :description, 'Financial Direct Deposit information for Veteran'
                key :required, %w[
                  accountType
                  accountNumber
                  routingNumber
                ]

                property :accountType do
                  key :type, :string
                  key :description, 'Veteran Account Type'
                  key :example, 'CHECKING'
                  key :enum, %w[CHECKING SAVINGS]
                end

                property :accountNumber do
                  key :type, :string
                  key :description, 'Veteran Bank Account Number'
                  key :example, '123123123123'
                end

                property :routingNumber do
                  key :type, :string
                  key :description, 'Veteran Bank Routing Number'
                  key :example, '123123123'
                end

                property :bankName do
                  key :type, :string
                  key :description, 'Veteran Bank Name'
                  key :example, 'Some Bank'
                end
              end

              property :claimantCertification do
                key :type, :boolean
                key :example, true
                key :description, 'Determines if person submitting the claim is certified to do so.'
              end

              property :standardClaim do
                key :type, :boolean
                key :example, false
                key :description, 'Determines if claim is considered a Standard Claim.'
              end

              property :autoCestPDFGenerationDisabled do
                key :type, :boolean
                key :example, false
                key :description, 'Allows you to bypass the auto PDF generation and instead upload the Disability form itself through Support Documents.'
              end

              property :claimDate do
                key :type, :string
                key :format, 'date'
                key :example, '2018-08-28'
                key :description, 'Date when claim is being submitted to the VA'
              end

              property :applicationExpirationDate do
                key :type, :string
                key :format, 'date-time'
                key :example, '2018-08-28T19:53:45+00:00'
                key :description, 'Time stamp of when claim expires in one year after submission.'
              end
            end
          end
        end

        schema :Form526Response do
          key :description, 'Claim submission beginning response'

          property :id do
            key :type, :string
            key :example, 'a9b20bfe-56b1-419e-89f9-d13d49def880'
            key :description, 'Internal vets-api Claim ID'
          end

          property :type do
            key :type, :string
            key :example, 'claims_api_claim'
            key :description, 'Required by JSON API standard'
          end

          property :attributes do
            key :type, :object
            key :description, 'Required by JSON API standard'

            property :evss_id do
              key :type, :string
              key :example, nil
              key :description, 'EVSS Claim ID'
            end

            property :date_filed do
              key :type, :string
              key :format, 'date'
              key :example, nil
              key :description, 'Date in YYYY-MM-DD the claim was first filed'
            end

            property :min_est_date do
              key :type, :string
              key :format, 'date'
              key :example, nil
              key :description, 'Minimum Estimated Claim Completion Date'
            end

            property :max_est_date do
              key :type, :string
              key :format, 'date'
              key :example, nil
              key :description, 'Maximum Estimated Claim Completion Date'
            end

            property :phase_change_date do
              key :type, :string
              key :format, 'date'
              key :example, nil
              key :description, 'Date of last phase change'
            end

            property :open do
              key :type, :boolean
              key :example, true
              key :description, 'Has the claim been resolved'
            end

            property :waiver_submitted do
              key :type, :boolean
              key :example, nil
              key :description, 'Requested Decision or Waiver 5103 Submitted'
            end

            property :documents_needed do
              key :type, :boolean
              key :example, nil
              key :description, 'Does the claim require additional documents to be submitted'
            end

            property :development_letter_sent do
              key :type, :boolean
              key :example, nil
              key :description, 'Indicates if a Development Letter has been sent to the Claimant regarding a benefit claim'
            end

            property :decision_letter_sent do
              key :type, :boolean
              key :example, nil
              key :description, 'Indicates if a Decision Letter has been sent to the Claimant regarding a benefit claim'
            end

            property :phase do
              key :type, :string
              key :example, nil
              key :description, ''
            end

            property :ever_phase_back do
              key :type, :string
              key :example, nil
              key :description, ''
            end

            property :current_phase_back do
              key :type, :string
              key :example, nil
              key :description, ''
            end

            property :requested_decision do
              key :type, :boolean
              key :example, nil
              key :description, 'The claim filer has requested a claim decision be made'
            end

            property :claim_type do
              key :type, :string
              key :example, nil
              key :description, 'The type of claim originally submitted'
              key :enum, [
                'Compensation',
                'Compensation and Pension',
                'Dependency'
              ]
            end

            property :updated_at do
              key :type, :string
              key :format, 'date-time'
              key :example, '2018-07-30T17:31:15.958Z'
              key :description, 'Time stamp of last change to the claim'
            end

            property :contention_list do
              key :type, :string
              key :example, nil
              key :description, ''
            end

            property :va_representative do
              key :type, :string
              key :example, nil
              key :description, ''
            end

            property :events_timeline do
              key :type, :string
              key :example, []
              key :description, ''
            end

            property :token do
              key :type, :string
              key :example, 'a9b20bfe-56b1-419e-89f9-d13d49def880'
              key :description, ''
            end

            property :status do
              key :type, :string
              key :example, 'pending'
              key :description, 'Current status of the claim'
              key :enum, [
                '"pending"',
                '"submitted"',
                '"established"',
                '"errored"'
              ]
            end

            property :flashes do
              key :type, :Array
              key :example, []
              key :description, 'List of existing flashes for this Veteran'
            end
          end
        end
      end
    end
  end
end
