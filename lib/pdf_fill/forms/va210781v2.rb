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
      START_PAGE = 8

      # Maps behavior keys to their corresponding descriptive text for the form's behavioral changes section
      BEHAVIOR_DESCRIPTIONS = {
        'consultations' => 'Increased/decreased visits to a healthcare professional, counselor, or treatment facility',
        'reassignment' => 'Request for a change in occupational series or duty assignment',
        'absences' => 'Increased/decreased use of leave',
        'performance' => 'Changes in performance or performance evaluations',
        'episodes' => 'Episodes of depression, panic attacks, or anxiety',
        'medications' => 'Increased/decreased use of prescription medications',
        'selfMedication' => 'Increased/decreased use of over-the-counter medications',
        'substances' => 'Increased/Decreased use of alcohol or drugs',
        'misconduct' => 'Disciplinary or legal difficulties',
        'appetite' => 'Changes in eating habits, such as overeating or under eating, or significant changes in weight',
        'pregnancy' => 'Pregnancy tests around the time of the traumatic events',
        'screenings' => 'Tests for sexually transmitted infections',
        'socialEconomic' => 'Economic or social behavioral changes',
        'relationships' => 'Changes in or breakup of a significant relationship'
      }.freeze

      # rubocop:disable Layout/LineLength
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'F[0].#subform[2].Veterans_Service_Members_First_Name[0]',
            limit: 12, # limit: 28 (with combs removed)
            question_num: 1,
            question_suffix: 'A',
            question_label: 'First',
            question_text: 'VETERAN/SERVICE MEMBER\'S NAME. First Name'
          },
          'middleInitial' => {
            key: 'F[0].#subform[2].VeteransMiddleInitial1[0]',
            limit: 1,
            question_num: 1,
            question_suffix: 'B',
            question_label: 'Middle Initial',
            question_text: 'VETERAN/SERVICE MEMBER\'S NAME. Middle Initial'
          },
          'last' => {
            key: 'F[0].#subform[2].VeteransLastName[0]',
            limit: 18, # limit: 45 (with combs removed)
            question_num: 1,
            question_suffix: 'C',
            question_label: 'Last',
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
        'veteranIntPhone' => {
          key: 'F[0].#subform[2].International_Telephone_Number_If_Applicable[0]',
          limit: 25,
          question_num: 6,
          question_suffix: 'D',
          question_text: 'Enter International Phone Number (If applicable).'
        },
        'email' => {
          key: 'F[0].#subform[2].E_Mail_Address_Optional[0]',
          limit: 75, # TODO: This is a guess.  Need to confirm.
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
        'events' => {
          limit: 6,
          first_key: 'details',
          item_label: 'Event',
          question_text: 'Traumatic event(s) information',
          question_num: 9,
          'details' => {
            key: "F[0].#subform[2].Brief_Description_Of_The_Traumatic_Events[#{ITERATOR}]",
            question_num: 9,
            question_suffix: 'A',
            question_text: 'Description',
            limit: 105
          },
          'location' => {
            key: "F[0].#subform[2].Location_Of_The_Traumatic_Events[#{ITERATOR}]",
            question_num: 9,
            question_suffix: 'B',
            question_text: 'Location',
            limit: 84
          },
          'timing' => {
            key: "F[0].#subform[2].Dates_The_Traumatic_Events_Occured[#{ITERATOR}]",
            question_num: 9,
            question_suffix: 'C',
            question_text: 'Date',
            limit: 75
          },
          'eventOverflow' => {
            key: '',
            question_text: 'TRAUMATIC EVENT(S) INFORMATION',
            question_num: 9,
            question_suffix: 'A'
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
          limit: 14,
          first_key: 'additionalInfo',
          item_label: 'Behavioral Change',
          question_text: 'Behavioral Changes Following In-service Personal Traumatic Event(s)',
          question_type: 'checked_description',
          question_num: 10,
          label_all: true,
          format_options: {
            label_width: 140
          },
          'description' => {
            key: '',
            limit: 105,
            question_num: 10,
            question_suffix: 'A',
            question_text: 'Description of Behavioral Change',
            question_label: 'Description',
            format_options: {
              bold_value: true,
              bold_label: true
            }
          },
          'checked' => {
            key: '',
            question_num: 10,
            question_suffix: 'A',
            question_text: 'Checked'
          },
          'additionalInfo' => {
            key: "F[0].#subform[3].Additional_Information_About_Behavioral_Changes[#{ITERATOR}]",
            limit: 217,
            question_num: 10,
            question_suffix: 'B',
            question_text: 'Additional Information about Behavioral Changes',
            question_label: 'Additional Information'
          }
        },
        'additionalBehaviorsDetails' => { # question_num: 10C
          limit: 1,
          first_key: 'additionalInfo',
          item_label: 'Behavioral Change',
          question_text: 'Behavioral Changes Following In-service Personal Traumatic Event(s)',
          question_type: 'checked_description',
          question_num: 10,
          override_index: 14,
          format_options: {
            label_width: 140
          },
          'description' => {
            key: '',
            question_num: 10,
            question_suffix: 'C',
            question_text: 'Description',
            format_options: {
              bold_value: true,
              bold_label: true
            }
          },
          'checked' => {
            key: '',
            question_num: 10,
            question_suffix: 'C',
            question_text: 'Checked'
          },
          'additionalInfo' => {
            key: 'F[0].#subform[4].List_Additional_Behavioral_Changes[0]',
            limit: 784,
            question_num: 10,
            question_suffix: 'C',
            question_text: 'Additional Information about unlisted behavioral changes',
            question_label: 'Additional Information'
          }
        },
        'reportFiled' => { # question_num: 11
          key: 'F[0].#subform[4].Report_Yes[0]'
        },
        'noReportFiled' => { # question_num: 11
          key: 'F[0].#subform[4].Report_No[0]'
        },
        'restrictedReport' => { # question_num: 11
          question_num: 11,
          question_label: 'Restricted military incident report',
          question_type: 'checklist_group',
          checked_values: ['0'],
          key: 'F[0].#subform[4].Restricted[0]'
        },
        'unrestrictedReport' => { # question_num: 11
          question_num: 11,
          question_label: 'Unrestricted military incident report',
          question_type: 'checklist_group',
          checked_values: ['1'],
          key: 'F[0].#subform[4].Unrestricted[0]'
        },
        'neitherReport' => { # question_num: 11
          question_num: 11,
          question_label: 'Military incident report (unspecified restriction)',
          question_type: 'checklist_group',
          checked_values: ['2'],
          key: 'F[0].#subform[4].Neither[0]'
        },
        'policeReport' => { # question_num: 11
          question_num: 11,
          question_label: 'Police report',
          question_type: 'checklist_group',
          checked_values: ['3'],
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
            question_label: 'Other',
            question_type: 'checklist_group',
            question_text: 'Other Report'
          },
          'otherOverflow' => {
            key: '',
            question_num: 11,
            question_suffix: 'B',
            question_text: 'Other Report'
          }
        },
        'policeReportOverflow' => { # question 11.5 (number hidden) only when reportsDetails.police overflows
          limit: 0,
          item_label: 'Location',
          'agency' => {
            question_suffix: 'A',
            question_num: 11.5,
            question_text: 'Agency'
          },
          'city' => {
            question_suffix: 'B',
            question_num: 11.5,
            question_text: 'City'
          },
          'state' => {
            question_suffix: 'C',
            question_num: 11.5,
            question_text: 'State/Province'
          },
          'country' => {
            question_suffix: 'D',
            question_num: 11.5,
            question_text: 'Country'
          }
        },
        'evidence' => { # question_num: 12
          'crisis' => {
            question_num: 12,
            question_label: 'A rape crisis center or center for domestic abuse',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].A_Rape_Crisis_Center_Or_Center_For_Domestic_Abuse[0]'
          },
          'counseling' => {
            question_num: 12,
            question_label: 'A counseling facility or health clinic',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].A_Counseling_Facility_Or_Health_Clinic[0]'
          },
          'family' => {
            question_num: 12,
            question_label: 'Family members or roommates',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].Family_Member_Or_Roomates[0]'
          },
          'faculty' => {
            question_num: 12,
            question_label: 'A faculty member',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].A_Faculty_Member[0]'
          },
          'police' => {
            question_num: 12,
            question_label: 'Civilian police reports',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].Civilian_Police_Reports[0]'
          },
          'physicians' => {
            question_num: 12,
            question_label: 'Medical reports from civilian physicians or caregivers',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].Medical_Reports_From_Civilian_Physicians_Or_Caregivers_Who_Treated_You_Immediately_Following_The_Incident_Or_Sometime_Later[0]'
          },
          'clergy' => {
            question_num: 12,
            question_label: 'A chaplain or clergy',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].A_Chaplain_Or_Clergy[0]'
          },
          'service' => {
            question_num: 12,
            question_label: 'Fellow service member(s)',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].Fellow_Service_Members[0]'
          },
          'personal' => {
            question_num: 12,
            question_label: 'Personal diaries or journals',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].Personal_Diaries_Or_Journals[0]'
          },
          'none' => {
            question_num: 12,
            question_label: 'None',
            question_type: 'checklist_group',
            checked_values: ['1'],
            key: 'F[0].#subform[4].No_Evidence[0]'
          },
          'other' => {
            question_num: 12,
            key: 'F[0].#subform[4].Other_Specify_Below[0]'
          },
          'otherDetails' => {
            key: 'F[0].#subform[4].Other_Evidence[0]',
            limit: 100,
            question_num: 12,
            question_label: 'Other',
            question_type: 'checklist_group',
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
          'nonVa' => {
            key: 'F[0].#subform[4].Private_Healthcare_Provider[0]'
          },
          'vaCenters' => {
            key: 'F[0].#subform[4].VA_Vet_Center[0]'
          },
          'vaPaid' => {
            key: 'F[0].#subform[4].Community_Care_Paid_For_By_VA[0]'
          },
          'medicalCenter' => {
            key: 'F[0].#subform[4].VA_Medical_Center_And_Community_Based_Outpatient_Clinics[0]'
          },
          'communityOutpatient' => {
            key: 'F[0].#subform[4].VA_Medical_Center_And_Community_Based_Outpatient_Clinics[0]'
          },
          'dod' => {
            key: 'F[0].#subform[4].Department_Of_Defense_Military_Treatment_Facilities[0]'
          }
        },
        'treatmentProvidersDetails' => {
          limit: 3,
          first_key: 'facilityInfo',
          item_label: 'Treatment facility',
          question_text: 'TREATMENT INFORMATION',
          question_num: 13,
          format_options: {
            label_width: 140
          },
          'facilityInfo' => {
            key: "F[0].#subform[5].Name_And_Location_Of_Treatment_Facility[#{ITERATOR}]",
            question_num: 13,
            question_suffix: 'C',
            question_text: 'Facility name',
            limit: 100
          },
          'treatmentMonth' => {
            key: "F[0].#subform[5].Date_Of_Treatment_Month[#{ITERATOR}]",
            limit: 2
          },
          'treatmentYear' => {
            key: "F[0].#subform[5].Date_Of_Treatment_Year[#{ITERATOR}]",
            limit: 4
          },
          'noDates' => {
            key: "F[0].#subform[5].Check_Box_Do_Not_Have_Date_s[#{ITERATOR}]"
          },
          'treatmentDate' => {
            question_num: 13,
            question_suffix: 'D',
            question_text: 'Treatment date'
          },
          'providerOverflow' => {
            key: '',
            question_text: 'TREATMENT INFORMATION',
            question_num: 13,
            question_suffix: 'C'
          }
        },
        'additionalInformation' => {
          key: 'F[0].#subform[5].Remarks_If_Any[0]',
          limit: 1940,
          question_num: 14,
          question_text: 'REMARKS',
          question_type: 'free_text'
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
          key: 'F[0].#subform[5].Signature[0]',
          limit: 50, # TODO: This is a guess.  Need to confirm.
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
      # rubocop:enable Layout/LineLength

      QUESTION_KEY = {
        1 => 'Veteran/Service member\'s name',
        2 => 'Social security number',
        3 => 'VA file number',
        4 => 'Date of birth',
        5 => 'Veteran\'s service number',
        6 => 'Telephone number',
        7 => 'Email address',
        8 => 'Type of in-service traumatic event(s)',
        9 => 'Traumatic event(s) information',
        10 => 'Behavioral Changes Following In-service Personal Traumatic Event(s)',
        11 => 'Was an official report filed?',
        11.5 => 'Police report location(s)',
        12 => 'Possible sources of evidence following the traumatic event(s)',
        13 => 'Treatment information',
        14 => 'Remarks',
        16 => 'Veteran/service member\'s signature'
      }.freeze

      SECTIONS = [
        {
          label: 'Section I: Veteran\'s Identification Information',
          question_nums: (1..7).to_a
        },
        {
          label: 'Section II: Traumatic Event(s) Information',
          question_nums: [8, 9]
        },
        {
          label: 'Section III: Additional Information Associated with the In-service Traumatic Event(s)',
          question_nums: [10, 11, 11.5, 12]
        },
        {
          label: 'Section IV: Treatment Information',
          question_nums: [13]
        },
        {
          label: 'Section V: Remarks',
          question_nums: [14]
        },
        {
          label: 'Section VII: Certification and Signature',
          question_nums: [15]
        }
      ].freeze

      def merge_fields(options = {})
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
        @form_data = expand_ssn(@form_data)
        @form_data['veteranDateOfBirth'] = expand_veteran_dob(@form_data)

        split_phone(@form_data, 'veteranPhone')

        set_treatment_selection
        set_option_indicator

        if @form_data['events']&.any?
          process_reports
          expand_collection('events', :format_event, 'eventOverflow') unless options[:extras_redesign]
        end

        process_treatment_providers_details(options[:extras_redesign])

        process_behaviors_details(options[:extras_redesign]) if @form_data['behaviorsDetails']&.any?

        expand_signature(@form_data['veteranFullName'], @form_data['signatureDate'])

        formatted_date = DateTime.parse(@form_data['signatureDate']).strftime('%Y-%m-%d')
        @form_data['signatureDate'] = split_date(formatted_date)
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        @form_data
      end

      def process_treatment_providers_details(extras_redesign)
        if extras_redesign
          process_treatment_dates
        else
          expand_collection('treatmentProvidersDetails', :format_provider, 'providerOverflow')
        end
      end

      private

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

      def sanitize_phone(phone)
        phone.gsub('-', '')
      end

      def set_treatment_selection
        treated = (@form_data['treatmentProviders'] || {}).any?
        not_treated = @form_data['treatmentNoneCheckbox']&.[]('none') || false

        return if !treated && !not_treated

        @form_data['treatment'] = treated ? 0 : 1
        @form_data['noTreatment'] = not_treated ? 1 : 0
      end

      def process_reports
        report_filed = false
        no_report = false
        police_reports = []
        unlisted_reports = []
        reports_details = @form_data['reportsDetails'] ||= {}

        @form_data['events'].each do |event|
          reports = merge_reports(event)
          unlisted_report = event['unlistedReport']
          next if reports.empty? && unlisted_report&.blank?

          report_filed ||= reports.except('none').values.include?(true)
          no_report ||= reports['none']

          set_report_types(reports, unlisted_report)

          police_report = format_police_details(event)
          police_reports << police_report unless police_report.empty?

          unlisted_reports << unlisted_report if unlisted_report.present?
        end

        @form_data['reportFiled'] = report_filed ? 0 : nil
        @form_data['noReportFiled'] = no_report && !report_filed ? 1 : nil

        process_police_reports(police_reports)
        reports_details['other'] = unlisted_reports.join('; ') unless unlisted_reports.empty?
      end

      def process_police_reports(police_reports)
        return if police_reports.empty?

        joined_report = police_reports.join('; ')
        @form_data['reportsDetails']['police'] = joined_report
        return if joined_report.length <= (KEY['reportsDetails']['police'][:limit] || 0)

        police_events = @form_data['events'].filter { |event| event.dig('otherReports', 'police') }
        @form_data['policeReportOverflow'] = police_events.map do |event|
          event.slice(*%w[agency city state township country])
        end
      end

      def process_treatment_dates
        @form_data['treatmentProvidersDetails'].each do |item|
          item['noDates'] = item['treatmentMonth'].to_s.strip.empty? && item['treatmentYear'].to_s.strip.empty?
          item['treatmentDate'] = if item['noDates']
                                    'no response'
                                  else
                                    [item['treatmentMonth'], item['treatmentYear'] || '????'].compact.join('-')
                                  end
        end
      end

      def process_standard_behaviors(behaviors_details, extras_redesign)
        @form_data['behaviorsDetails'] = BEHAVIOR_DESCRIPTIONS.map do |k, v|
          # If the behavior is present, that means the checkbox was checked,
          # so add the additional info, even if there was no response.
          item = { 'additionalInfo' => behaviors_details[k] }
          item['checked'] = behaviors_details.key?(k) if extras_redesign
          item['description'] = v
          item
        end
      end

      def process_behaviors_details(extras_redesign)
        behaviors_details = @form_data['behaviorsDetails']
        return if behaviors_details.blank?

        process_standard_behaviors(behaviors_details, extras_redesign)

        unless extras_redesign
          @form_data['behaviorsDetails'].select { |item| item['additionalInfo'].blank? }.each do |item|
            item['description'] = nil
          end
        end

        additional = { 'additionalInfo' => behaviors_details['unlisted'] }
        if extras_redesign
          additional['checked'] = true
          additional['description'] = 'Additional Behavioral Changes'
          @form_data['additionalBehaviorsDetails'] = [additional]
        else
          @form_data['additionalBehaviorsDetails'] = additional
        end
      end

      def merge_reports(event)
        (event['militaryReports'] || {})
          .merge(event['otherReports'] || {})
          .merge('unlistedReport' => event['unlistedReport'])
      end

      # Numbers correspond to a predefined "export value" assigned to each checkbox option on the PDF form:
      def set_report_types(reports, unlisted_report)
        @form_data['restrictedReport'] ||= reports['restricted'] ? 0 : nil
        @form_data['unrestrictedReport'] ||= reports['unrestricted'] ? 1 : nil
        @form_data['neitherReport'] ||= reports['pre2005'] ? 2 : nil
        @form_data['policeReport'] ||= reports['police'] ? 3 : nil
        @form_data['otherReport'] ||= reports['unsure'] || unlisted_report ? 4 : nil
      end

      def set_option_indicator
        selected_option = @form_data['optionIndicator']
        valid_options = %w[yes no revoke notEnrolled]

        return if selected_option.nil? || valid_options.exclude?(selected_option)

        @form_data['optionIndicator'] = valid_options.index_with { |_option| false }
        @form_data['optionIndicator'][selected_option] = true
      end

      def format_police_details(event)
        fields = %w[agency city state township country]
        fields.map { |field| event[field] }.compact_blank.join(', ')
      end

      def expand_collection(collection, format_method, overflow_key)
        limit = KEY[collection].try(:[], :limit) || 0
        collection = @form_data[collection]
        return if collection.blank?

        collection.each_with_index do |item, index|
          format_item_overflow(item, index + 1, format_method, overflow_key, overflow_only: collection.count > limit)
        end
      end

      # Gathers all visible fields in a list-and-loop item and concatenates them into an overflow field
      # for the legacy 21-0781v2 overflow page.
      # If overflow_only is true, the item has been moved from the PDF template to overflow, and the
      # original fields should be removed so as not to duplicate the concatenated overflow field.
      def format_item_overflow(item, index, format_method, overflow_key, overflow_only: false)
        item_overflow = send(format_method, item, index, overflow_only:)
        return if item_overflow.blank?

        item[overflow_key] = PdfFill::FormValue.new('', item_overflow.compact.join("\n\n"))
      end

      def format_event(event, index, overflow_only: false)
        return if event.blank?

        event_overflow = ["Event Number: #{index}"]
        event_details = event['details'] || ''
        event_location = event['location'] || ''
        event_timing = event['timing'] || ''

        event_overflow.push("Event Description: \n\n#{event_details}")
        event_overflow.push("Event Location: \n\n#{event_location}")
        event_overflow.push("Event Date: \n\n#{event_timing}")

        # Remove these from legacy overflow page to avoid duplication with concatenated field
        %w[details location timing].each { |key| event[key] = nil } if overflow_only

        event_overflow
      end

      def format_provider(provider, index, overflow_only: false)
        return if provider.blank?

        provider_overflow = ["Treatment Information Number: #{index}"]
        facility_info = provider['facilityInfo']
        month = provider['treatmentMonth'] || 'XX'
        year = provider['treatmentYear'] || 'XXXX'
        no_date = provider['treatmentMonth'].to_s.strip.empty? && provider['treatmentYear'].to_s.strip.empty?
        provider['noDates'] = no_date

        provider_overflow.push("Treatment Facility Name and Location: \n\n#{facility_info}")
        provider_overflow.push(no_date ? "Treatment Date: Don't have date" : "Treatment Date: #{month}-#{year}")

        # Remove these from legacy overflow page to avoid duplication with concatenated field
        %w[facilityInfo treatmentMonth treatmentYear].each { |key| provider[key] = nil } if overflow_only

        provider_overflow
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
