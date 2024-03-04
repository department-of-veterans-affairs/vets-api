# frozen_string_literal: true

module SimpleFormsApi
  class VBA264555
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def as_payload
      {
        remarks: data['remarks'],
        otherConditions: data['other_conditions'],
        livingSituation: {
          careFacilityName: data.dig('living_situation', 'care_facility_name'),
          careFacilityAddress: {
            street: data.dig('living_situation', 'care_facility_address', 'street'),
            street2: data.dig('living_situation', 'care_facility_address', 'street2'),
            city: data.dig('living_situation', 'care_facility_address', 'city'),
            state: data.dig('living_situation', 'care_facility_address', 'state'),
            postalCode: data.dig('living_situation', 'care_facility_address', 'postal_code')
          },
          isInCareFacility: data.dig('living_situation', 'is_in_care_facility')
        },
        previousHiApplication: {
          previousHiApplicationDate: data.dig('previous_hi_application', 'previous_hi_application_date'),
          previousHiApplicationAddress: {
            city: data.dig('previous_hi_application', 'previous_hi_application_address', 'city')
          },
          hasPreviousHiApplication: data.dig('previous_hi_application', 'has_previous_hi_application')
        },
        previousSahApplication: {
          previousSahApplicationDate: data.dig('previous_sah_application', 'previous_sah_application_date'),
          previousSahApplicationAddress: {
            city: data.dig('previous_sah_application', 'previous_sah_application_address', 'city')
          },
          hasPreviousSahApplication: data.dig('previous_sah_application', 'has_previous_sah_application')
        },
        veteran: {
          address: {
            isMilitary: data.dig('veteran', 'address', 'is_military'),
            country: data.dig('veteran', 'address', 'country'),
            street: data.dig('veteran', 'address', 'street'),
            street2: data.dig('veteran', 'address', 'street2'),
            city: data.dig('veteran', 'address', 'city'),
            state: data.dig('veteran', 'address', 'state'),
            postalCode: data.dig('veteran', 'address', 'postal_code')
          },
          ssn: data.dig('veteran', 'ssn'),
          vaFileNumber: data.dig('veteran', 'va_file_number'),
          fullName: {
            first: data.dig('veteran', 'full_name', 'first'),
            middle: data.dig('veteran', 'full_name', 'middle'),
            last: data.dig('veteran', 'full_name', 'last'),
            suffix: data.dig('veteran', 'full_name', 'suffix')
          },
          dateOfBirth: data.dig('veteran', 'date_of_birth')
        },
        statementOfTruthSignature: data['statement_of_truth_signature'],
        statementOfTruthCertified: data['statement_of_truth_certified'],
        formNumber: data['form_number']
      }
    end

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_address + previous_sah_application + previous_hi_application +
        living_situation + veteran_home_phone + veteran_mobile_phone + veteran_email
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_file_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def submission_date_config
      { should_stamp_date?: false }
    end

    def track_user_identity; end

    private

    def veteran_ssn
      [
        data.dig('veteran', 'ssn')&.[](0..2),
        data.dig('veteran', 'ssn')&.[](3..4),
        data.dig('veteran', 'ssn')&.[](5..8)
      ]
    end

    def veteran_date_of_birth
      [
        data.dig('veteran', 'date_of_birth')&.[](0..3),
        data.dig('veteran', 'date_of_birth')&.[](5..6),
        data.dig('veteran', 'date_of_birth')&.[](8..9)
      ]
    end

    def veteran_address
      [
        data.dig('veteran', 'address', 'postal_code')&.[](0..4),
        data.dig('veteran', 'address', 'postal_code')&.[](5..8)
      ]
    end

    def previous_sah_application
      [
        data.dig('previous_sah_application', 'previous_sah_application_address', 'postal_code')&.[](0..4),
        data.dig('previous_sah_application', 'previous_sah_application_address', 'postal_code')&.[](5..8)
      ]
    end

    def previous_hi_application
      [
        data.dig('previous_hi_application', 'previous_hi_application_address', 'postal_code')&.[](0..4),
        data.dig('previous_hi_application', 'previous_hi_application_address', 'postal_code')&.[](5..8)
      ]
    end

    def living_situation
      [
        data.dig('living_situation', 'care_facility_address', 'postal_code')&.[](0..4),
        data.dig('living_situation', 'care_facility_address', 'postal_code')&.[](5..8)
      ]
    end

    def veteran_home_phone
      [
        data.dig('veteran', 'home_phone')&.gsub('-', '')&.[](0..2),
        data.dig('veteran', 'home_phone')&.gsub('-', '')&.[](3..5),
        data.dig('veteran', 'home_phone')&.gsub('-', '')&.[](6..9)
      ]
    end

    def veteran_mobile_phone
      [
        data.dig('veteran', 'mobile_phone')&.gsub('-', '')&.[](0..2),
        data.dig('veteran', 'mobile_phone')&.gsub('-', '')&.[](3..5),
        data.dig('veteran', 'mobile_phone')&.gsub('-', '')&.[](6..9)
      ]
    end

    def veteran_email
      [
        data.dig('veteran', 'email')&.[](0..14),
        data.dig('veteran', 'email')&.[](15..)
      ]
    end
  end
end
