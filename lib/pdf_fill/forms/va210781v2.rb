# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/common_ptsd'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va210781v2 < FormBase
      include CommonPtsd

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'F[0].#subform[2].Veterans_Service_Members_First_Name[0]',
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'VETERAN/SERVICE MEMBER\'S NAME. First Name'
          },
          'middleInitial' => {
            key: 'F[0].#subform[2].VeteransMiddleInitial1[0]',
            limit: 1,
            question_num: 1,
            question_suffix: 'B',
            question_text: 'VETERAN/SERVICE MEMBER\'S NAME. Middle Initial'
          },
          'last' => {
            key: 'F[0].#subform[2].VeteransLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'C',
            question_text: 'VETERAN/SERVICE MEMBER\'S NAME. Last Name'
          }
        },
        'veteranSocialSecurityNumber' => { # question_num: 2
          'first' => {
            key: 'F[0].#subform[2].SSN1[0]'
          },
          'second' => {
            key: 'F[0].#subform[2].SSN2[0]'
          },
          'third' => {
            key: 'F[0].#subform[2].SSN3[0]'
          }
        },
        'vaFileNumber' => {
          key: 'F[0].#subform[2].VAFileNumber[0]',
          limit: 9,
          question_num: 3,
          question_text: 'VA FILE NUMBER (If applicable)'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'F[0].#subform[2].Month[0]',
            limit: 2,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'DATE OF BIRTH. Enter 2 digit Month.'
          },
          'day' => {
            key: 'F[0].#subform[2].Day[0]',
            limit: 2,
            question_num: 4,
            question_suffix: 'B',
            question_text: 'DATE OF BIRTH. Enter 2 digit day.'
          },
          'year' => {
            key: 'F[0].#subform[2].Year[0]',
            limit: 4,
            question_num: 4,
            question_suffix: 'C',
            question_text: 'DATE OF BIRTH. Enter 4 digit year.'
          }
        },
        'veteranServiceNumber' => {
          key: 'F[0].#subform[2].VeteransServiceNumber[0]',
          limit: 10,
          question_num: 5,
          question_text: 'VETERAN\'S SERVICE NUMBER (If applicable)'
        },
        'veteranPhone' => {
          'first' => {
            key: 'F[0].#subform[2].AreaCode[0]',
            limit: 3,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'TELEPHONE NUMBER (Include Area Code). Enter three digits of Area Code.'
          },
          'second' => {
            key: 'F[0].#subform[2].FirstThreeNumbers[0]',
            limit: 3,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'TELEPHONE NUMBER (Include Area Code). Enter middle three digits.'
          },
          'third' => {
            key: 'F[0].#subform[2].LastFourNumbers[0]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'TELEPHONE NUMBER (Include Area Code). Enter last four digits.'
          }
        },
        'veteranIntPhone' => { # TODO: Confirm phone type as it is different than current 0781 (secondary phone)
          key: 'F[0].#subform[2].International_Telephone_Number_If_Applicable[0]',
          limit: 25, # TODO: This is a guess.  Need to confirm.
          question_num: 6,
          question_suffix: 'D',
          question_text: 'Enter International Phone Number (If applicable).'
        },
        'veteranIntPhoneOverflow' => {
          key: '',
          question_num: 6,
          question_suffix: 'D',
          question_text: 'Enter International Phone Number (If applicable).'
        },
        'email' => {
          key: 'F[0].#subform[2].E_Mail_Address_Optional[0]',
          limit: 97, # TODO: This is a guess.  Need to confirm.
          question_num: 7,
          question_text: 'E-Mail Address (Optional).'
        },
        'emailOverflow' => {
          key: '',
          question_num: 7,
          question_text: 'E-Mail Address (Optional).'
        },
        'eventTypes' => { # question_num: 8
          'combat' => {
            key: 'F[0].#subform[2].Combat_Traumatic_Events[0]'
          },
          'mst' => {
            key: 'F[0].#subform[2].Personal_Traumatic_Events_Not_Involving_Military_Sexual_Trauma[0]'
          },
          'nonMst' => {
            key: 'F[0].#subform[2].Personal_Traumatic_Events_Involving_Military_Sexual_Trauma[0]'
          },
          'other' => {
            key: 'F[0].#subform[2].Other_Traumatic_Events[0]'
          }
        },
        'eventDetails' => {
          limit: 6,
          first_key: 'details',
          question_text: 'EVENT DETAILS',
          question_num: 9,
          'details' => {
            key: "F[0].#subform[2].Brief_Description_Of_The_Traumatic_Events[#{ITERATOR}]",
            limit: 150,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'BRIEF DESCRIPTION OF THE TRAUMATIC EVENT(S)'
          },
          'detailsOverflow' => {
            key: '',
            question_num: 9,
            question_suffix: 'A',
            question_text: 'BRIEF DESCRIPTION OF THE TRAUMATIC EVENT(S)'
          },
          'location' => {
            key: "F[0].#subform[2].Location_Of_The_Traumatic_Events[#{ITERATOR}]",
            limit: 84,
            question_num: 9,
            question_suffix: 'B',
            question_text: 'LOCATION OF THE TRAUMATIC EVENT(S)'
          },
          'locationOverflow' => {
            key: '',
            question_num: 9,
            question_suffix: 'B',
            question_text: 'LOCATION OF THE TRAUMATIC EVENT(S)'
          },
          'timing' => {
            key: "F[0].#subform[2].Dates_The_Traumatic_Events_Occured[#{ITERATOR}]",
            limit: 75,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'DATE(S) THE TRAUMATIC EVENT(S) OCCURRED'
          },
          'timingOverflow' => {
            key: '',
            question_num: 9,
            question_suffix: 'C',
            question_text: 'DATE(S) THE TRAUMATIC EVENT(S) OCCURRED'
          }
        },
        'behaviors' => { # question_num: 10A
          'reassignment' => {
            key: 'F[0].#subform[3].Request_For_A_Change_In_Occupational_Series_Or_Duty_Assignment[0]'
          },
          'absences' => {
            key: 'F[0].#subform[3].Increased_Decreased_Use_Of_Leave[0]'
          },
          'performance' => {
            key: 'F[0].#subform[3].Changes_In_Performance_Or_Performance_Evaluations[0]'
          },
          'consultations' => {
            key: 'F[0].#subform[3].Increased_Decreased_Visits_To_A_Healthcare_Professional_Counselor_Or_Treatment_Facility[0]'
          },
          'episodes' => {
            key: 'F[0].#subform[3].Episodes_Of_Depression_Panic_Attacks_Or_Anxiety[0]'
          },
          'medications' => {
            key: 'F[0].#subform[3].Increased_Decreased_Use_Of_Prescription_Medications[0]'
          },
          'selfMedication' => {
            key: 'F[0].#subform[3].Increased_Decreased_Use_Of_Over_The_Counter_Medications[0]'
          },
          'substances' => {
            key: 'F[0].#subform[3].Increased_Decreased_Use_Of_Alcohol_Or_Drugs[0]'
          },
          'appetite' => {
            key: 'F[0].#subform[3].Changes_In_Eating_Habits_Such_As_Overeating_Or_Undereating_Or_Significant_Changes_In_Weight[0]'
          },
          'pregnancy' => {
            key: 'F[0].#subform[4].Pregnancy_Tests_Around_The_Time_Of_The_Traumatic_Events[0]'
          },
          'screenings' => {
            key: 'F[0].#subform[4].Tests_For_Sexually_Transmitted_Infections[0]'
          },
          'socialEconomic' => {
            key: 'F[0].#subform[4].Economic_Or_Social_Behavioral_Changes[0]'
          },
          'relationships' => {
            key: 'F[0].#subform[4].Changes_In_Or_Breakup_Of_A_Significant_Relationship[0]'
          },
          'misconduct' => {
            key: 'F[0].#subform[3].Disciplinary_Or_Legal_Difficulties[0]'
          }
        },
        'behaviorsDetails' => { # question_num: 10B
          'reassignment' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[1]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[2]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Request for a change in occupational series or duty assignment.'
          },
          'reassignmentOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[2]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Request for a change in occupational series or duty assignment.'
          },
          'absences' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[2]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[3]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/decreased use of leave.'
          },
          'absencesOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[3]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/decreased use of leave.'
          },
          'performance' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[3]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[4]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Changes in performance or performance evaluations.'
          },
          'performanceOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[4]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Changes in performance or performance evaluations.'
          },
          'consultations' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[0]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[1]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/decreased visits to a healthcare professional, counselor, or treatment Facility'
          },
          'consultationsOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[1]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/decreased visits to a healthcare professional, counselor, or treatment Facility'
          },
          'episodes' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[4]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[5]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Episodes of depression, panic attacks, or anxiety.'
          },
          'episodesOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[5]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Episodes of depression, panic attacks, or anxiety.'
          },
          'medications' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[5]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[6]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/Decreased use of prescription medications.'
          },
          'medicationsOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[6]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/Decreased use of prescription medications.'
          },
          'selfMedication' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[6]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[7]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/Decreased use of over-the-counter medications.'
          },
          'selfMedicationOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[7]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/Decreased use of over-the-counter medications.'
          },
          'substances' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[7]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[8]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/Decreased use of alcohol or drugs.'
          },
          'substancesOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[8]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Increased/Decreased use of alcohol or drugs.'
          },
          'appetite' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[9]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[10]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Changes in eating habits, such as overeating or under eating, or significant changes in weight.'
          },
          'appetiteOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[10]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Changes in eating habits, such as overeating or under eating, or significant changes in weight.'
          },
          'pregnancy' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[10]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[11]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Pregnancy tests around the time of the traumatic event(s).'
          },
          'pregnancyOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[11]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Pregnancy tests around the time of the traumatic event(s).'
          },
          'screenings' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[11]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[12]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Tests for sexually transmitted infections.'
          },
          'screeningsOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[12]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Tests for sexually transmitted infections.'
          },
          'socialEconomic' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[12]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[13]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Economic or social behavioral changes.'
          },
          'socialEconomicOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[13]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Economic or social behavioral changes.'
          },
          'relationships' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[13]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[14]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Changes in or breakup of a significant relationship.'
          },
          'relationshipsOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[14]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Changes in or breakup of a significant relationship.'
          },
          'misconduct' => {
            key: 'F[0].#subform[3].Additional_Information_About_Behavioral_Changes[8]',
            limit: 217,
            question_num: 10,
            question_suffix: 'B[9]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Disciplinary or legal difficulties.'
          },
          'misconductOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'B[9]',
            question_text: 'ADDTIONAL INFORMATION ABOUT Disciplinary or legal difficulties.'
          },
          'otherBehavior' => {
            key: 'F[0].#subform[4].List_Additional_Behavioral_Changes[0]',
            limit: 784,
            question_num: 10,
            question_suffix: 'C',
            question_text: 'ADDTIONAL INFORMATION ABOUT Additional behavioral changes.'
          },
          'otherBehaviorOverflow' => {
            key: '',
            question_num: 10,
            question_suffix: 'C',
            question_text: 'ADDTIONAL INFORMATION ABOUT Additional behavioral changes.'
          }
        },
        'reportFiled' => { # question_num: 11
          key: 'F[0].#subform[4].Report_Yes[0]'
        },
        'noReportFiled' => { # question_num: 11
          key: 'F[0].#subform[4].Report_No[0]'
        },
        'restrictedReport' => { # question_num: 11
          key: 'F[0].#subform[4].Restricted[0]'
        },
        'unrestrictedReport' => { # question_num: 11
          key: 'F[0].#subform[4].Unrestricted[0]'
        },
        'neitherReport' => { # question_num: 11
          key: 'F[0].#subform[4].Neither[0]'
        },
        'policeReport' => { # question_num: 11
          key: 'F[0].#subform[4].Police[0]'
        },
        'otherReport' => { # question_num: 11
          key: 'F[0].#subform[4].Other[1]'
        },
        'reportsDetails' => {
          'police' => {
            key: 'F[0].#subform[4].Police_Report_Location_If_Known[0]',
            limit: 68,
            question_num: 11,
            question_suffix: 'A',
            question_text: 'Police Report Location'
          },
          'policeOverflow' => {
            key: '',
            question_num: 11,
            question_suffix: 'A',
            question_text: 'Police Report Location'
          },
          'other' => {
            key: 'F[0].#subform[4].Other_Report[0]',
            limit: 194,
            question_num: 11,
            question_suffix: 'B',
            question_text: 'Other Report'
          },
          'otherOverflow' => {
            key: '',
            question_num: 11,
            question_suffix: 'B',
            question_text: 'Other Report'
          }
        },
        'evidence' => { # question_num: 12
          'crisisCenter' => {
            key: 'F[0].#subform[4].A_Rape_Crisis_Center_Or_Center_For_Domestic_Abuse[0]'
          },
          'counseling' => {
            key: 'F[0].#subform[4].A_Counseling_Facility_Or_Health_Clinic[0]'
          },
          'family' => {
            key: 'F[0].#subform[4].Family_Member_Or_Roomates[0]'
          },
          'faculty' => {
            key: 'F[0].#subform[4].A_Faculty_Member[0]'
          },
          'police' => {
            key: 'F[0].#subform[4].Civilian_Police_Reports[0]'
          },
          'medical' => {
            key: 'F[0].#subform[4].Medical_Reports_From_Civilian_Physicians_Or_Caregivers_Who_Treated_You_Immediately_Following_The_Incident_Or_Sometime_Later[0]'
          },
          'clergy' => {
            key: 'F[0].#subform[4].A_Chaplain_Or_Clergy[0]'
          },
          'peers' => {
            key: 'F[0].#subform[4].Fellow_Service_Members[0]'
          },
          'journal' => {
            key: 'F[0].#subform[4].Personal_Diaries_Or_Journals[0]'
          },
          'none' => {
            key: 'F[0].#subform[4].No_Evidence[0]'
          },
          'other' => {
            key: 'F[0].#subform[4].Other_Specify_Below[0]'
          },
          'otherDetails' => {
            key: 'F[0].#subform[4].Other_Evidence[0]',
            limit: 100,
            question_num: 12,
            question_text: 'OTHER'
          },
          'otherDetailsOverflow' => {
            key: '',
            question_num: 12,
            question_text: 'ADDITIONAL OTHER EVIDENCE DETAILS'
          }
        },
        'treatment' => { # question_num: 13A
          key: 'F[0].#subform[4].Treatment_Yes[0]'
        },
        'noTreatment' => { # question_num: 13A
          key: 'F[0].#subform[4].Treatment_No[0]'
        },
        'treatmentProviders' => { # question_num: 13B
          'privateCare' => {
            key: 'F[0].#subform[4].Private_Healthcare_Provider[0]'
          },
          'vetCenter' => {
            key: 'F[0].#subform[4].VA_Vet_Center[0]'
          },
          'communityCare' => {
            key: 'F[0].#subform[4].Community_Care_Paid_For_By_VA[0]'
          },
          'vamc' => {
            key: 'F[0].#subform[4].VA_Medical_Center_And_Community_Based_Outpatient_Clinics[0]'
          },
          'cboc' => {
            key: 'F[0].#subform[4].VA_Medical_Center_And_Community_Based_Outpatient_Clinics[0]'
          },
          'mtf' => {
            key: 'F[0].#subform[4].Department_Of_Defense_Military_Treatment_Facilities[0]'
          }
        },
        'treatmentProvidersDetails' => {
          limit: 3,
          first_key: 'facilityInfo',
          question_text: 'TREATMENT INFORMATION',
          question_num: 13,
          'facilityInfo' => {
            key: "F[0].#subform[5].Name_And_Location_Of_Treatment_Facility[#{ITERATOR}]",
            limit: 100,
            question_num: 13,
            question_suffix: 'C',
            question_text: 'NAME AND LOCATION OF THE TREATMENT FACILITY'
          },
          'treatmentMonth' => {
            key: "F[0].#subform[5].Date_Of_Treatment_Month[#{ITERATOR}]",
            limit: 2,
            question_num: 13,
            question_suffix: 'D',
            question_text: 'DATE(S) OF TREATMENT. Enter 2 digit Month.'
          },
          'treatmentYear' => {
            key: "F[0].#subform[5].Date_Of_Treatment_Year[#{ITERATOR}]",
            limit: 4,
            question_num: 13,
            question_suffix: 'D',
            question_text: 'DATE(S) OF TREATMENT. Enter 4 digit year.'
          },
          'noDates' => {
            key: "F[0].#subform[5].Check_Box_Do_Not_Have_Date_s[#{ITERATOR}]"
          },
          'description1' => {
            always_overflow: true
          },
          'treatmentOverflow' => {
            key: '',
            question_text: 'TREATMENT INFORMATION',
            question_num: 13,
            question_suffix: 'E'
          }
        },
        'additionalInformation' => {
          key: 'F[0].#subform[5].Remarks_If_Any[0]',
          limit: 1940,
          question_num: 14,
          question_text: 'REMARKS'
        },
        'additionalInformationOverflow' => {
          key: '',
          question_num: 14,
          question_text: 'ADDITIONAL REMARKS'
        },
        'optionIndicator' => { # question_num: 15
          'yes' => {
            key: 'F[0].#subform[5].I_Consent_To_Have_VBA_Notify_VHA_About_Certain_Upcoming_Events_Related_To_My_Claim_And_Or_Appeal[0]'
          },
          'no' => {
            key: 'F[0].#subform[5].I_Do_Not_Consent_To_Have_VBA_Notify_VHA_About_Certain_Upcoming_Events_Related_To_My_Claim_And_Or_Appeal[0]'
          },
          'revoke' => {
            key: 'F[0].#subform[5].I_Revoke_Prior_Consent_To_Have_VBA_Notify_VHA_About_Certain_Upcoming_Events_Related_To_My_Claim_And_Or_Appeal[0]'
          },
          'notEnrolled' => {
            key: 'F[0].#subform[5].Not_Applicable_And_Or_Not_Enrolled_In_VHA_Healthcare[0]'
          }
        },
        'signature' => {
          key: 'F[0].#subform[5].Digital_Signature[0]', 
          question_num: 16,
          question_suffix: 'A',
          question_text: 'VETERAN/SERVICE MEMBER\'S SIGNATURE'
        },
        'signatureDate' => {
          'month' => {
            key: 'F[0].#subform[5].Date_Signed_Month[0]',
            limit: 2,
            question_num: 16,
            question_suffix: 'B',
            question_text: 'DATE SIGNED. Enter 2 digit month.'
          },
          'day' => {
            key: 'F[0].#subform[5].Date_Signed_Day[0]',
            limit: 2,
            question_num: 16,
            question_suffix: 'B',
            question_text: 'DATE SIGNED. Enter 2 digit day.'
          },
          'year' => {
            key: 'F[0].#subform[5].Date_Signed_Year[0]',
            limit: 4,
            question_num: 16,
            question_suffix: 'B',
            question_text: 'DATE SIGNED. Enter 4 digit Year.'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
        @form_data = expand_ssn(@form_data)
        @form_data['veteranDateOfBirth'] = expand_veteran_dob(@form_data)
        
        split_phone(@form_data, 'veteranPhone')

        # special case: these fields were built as checkboxes instead of radios, so usual radio logic cannot be used.
        treated = @form_data['traumaTreatment']
        @form_data['treatment'] = treated ? 0 : 1
        @form_data['noTreatment'] = treated ? 0 : 1

        # special case: these fields were built as checkboxes instead of radios, so usual radio logic cannot be used.
        reports = @form_data['reports']
        @form_data['reportFiled'] = reports['yes'] ? 0 : nil
        @form_data['noReportFiled'] = reports['no'] ? 1 : nil
        @form_data['restrictedReport'] = reports['restricted'] ? 0 : nil
        @form_data['unrestrictedReport'] = reports['unrestricted'] ? 1 : nil
        @form_data['neitherReport'] = reports['neither'] ? 2 : nil
        @form_data['policeReport'] = reports['police'] ? 3 : nil
        @form_data['otherReport'] = reports['other'] ? 4 : nil

        format_other_behavior_details
        format_police_report_location

        event_details = @form_data['eventDetails']
        provider_details = @form_data['treatmentProvidersDetails']
        
        expand_overflow(event_details, :format_event, 'eventOverflow')
        expand_overflow(provider_details, :format_treatment, 'treatmentOverflow')

        expand_signature(@form_data['veteranFullName'], @form_data['signatureDate'])
        
        formatted_date = DateTime.parse(@form_data['signatureDate']).strftime("%Y-%m-%d")
        @form_data['signatureDate'] = split_date(formatted_date)
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        @form_data
      end

      private

      def format_other_behavior_details
        behavior = @form_data['behaviors']['otherBehavior']
        return unless behavior.present?

        details = @form_data['behaviorsDetails']['otherBehavior']
        @form_data['behaviorsDetails']['otherBehavior'] = "#{behavior}: #{details}"
      end

      def format_police_report_location
        report = @form_data['reportsDetails']['police']
        return if report.blank?

        @form_data['reportsDetails']['police'] = report.values.reject(&:empty?).join(', ')
      end

      def expand_overflow(collection, format_method, overflow_key)
        return if collection.blank?

        collection.each_with_index do |item, index|
          formatted_overflow = send(format_method, item, index + 1)
          next if formatted_overflow.nil?

          item[overflow_key] = PdfFill::FormValue.new('', formatted_overflow.compact.join("\n\n"))
        end
      end

      def format_event(event, index)
        return if event.blank?

        event_overflow = ["Event Number: #{index}"]
        event_details = event['details'] || ''
        event_location = event['location'] || ''
        event_timing = event['timing'] || ''

        event_overflow.push("Event Description: \n\n#{event_details}")
        event_overflow.push("Event Location: \n\n#{event_location}")
        event_overflow.push("Event Date(s): \n\n#{event_timing}")

        event_overflow
      end

      def format_treatment(treatment, index)
        return if treatment.blank?

        treatment_overflow = ["Treatment Information Number: #{index}"]
        facility_info = treatment['facilityInfo'] || ''
        month = treatment['treatmentMonth'] || ''
        year = treatment['treatmentYear'] || ''
        no_date = treatment['noDates']

        treatment_overflow.push("Treatment Facility Info: \n\n#{facility_info}")
        treatment_overflow.push(no_date ? "Treatment Date: Don't have date" : "Treatment Date: #{month}-#{year}")

        treatment_overflow
      end

      def sanitize_phone(phone)
        phone.gsub('-', '')
      end

      def split_phone(hash, key)
        phone = hash[key]
        return if phone.blank?

        phone = sanitize_phone(phone)
        hash[key] = {
          'first' => phone[0..2],
          'second' => phone[3..5],
          'third' => phone[6..9]
        }
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
