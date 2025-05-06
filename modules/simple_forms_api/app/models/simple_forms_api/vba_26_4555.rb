# frozen_string_literal: true

module SimpleFormsApi
  class VBA264555 < BaseForm
    def as_payload
      {
        remarks: data['remarks'],
        otherConditions: data['other_conditions'],
        livingSituation: living_situation_payload,
        previousHiApplication: previous_hi_application_payload,
        previousSahApplication: previous_sah_application_payload,
        veteran: veteran_payload,
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
        'fileNumber' => @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('veteran', 'full_name', 'first')
    end

    def notification_email_address
      data.dig('veteran', 'email')
    end

    def zip_code_is_us_based
      @data.dig('veteran', 'address', 'country') == 'USA'
    end

    def desired_stamps
      return [] unless data

      [].tap do |stamps|
        stamps << { coords: [73, 390], text: 'X' } unless data.dig('previous_sah_application',
                                                                   'has_previous_sah_application')
        stamps << { coords: [73, 355], text: 'X' } unless data.dig('previous_hi_application',
                                                                   'has_previous_hi_application')
        stamps << { coords: [73, 320], text: 'X' } unless data.dig('living_situation', 'is_in_care_facility')
      end.compact
    end

    def submission_date_stamps(_timestamp)
      []
    end

    def track_user_identity(confirmation_number); end

    private

    def living_situation_payload
      care_facility_address = data.dig('living_situation', 'care_facility_address')
      {
        careFacilityName: data.dig('living_situation', 'care_facility_name'),
        careFacilityAddress: {
          street: care_facility_address&.fetch('street', nil),
          street2: care_facility_address&.fetch('street2', nil),
          city: care_facility_address&.fetch('city', nil),
          state: care_facility_address&.fetch('state', nil),
          postalCode: care_facility_address&.fetch('postal_code', nil)
        },
        isInCareFacility: data.dig('living_situation', 'is_in_care_facility')
      }
    end

    def previous_hi_application_payload
      if data.dig('previous_hi_application', 'has_previous_hi_application')
        {
          previousHiApplicationDate: data.dig('previous_hi_application', 'previous_hi_application_date'),
          previousHiApplicationAddress: {
            city: data.dig('previous_hi_application', 'previous_hi_application_address', 'city')
          },
          hasPreviousHiApplication: data.dig('previous_hi_application', 'has_previous_hi_application'),
          previousHiApplicationLocation: data.dig('previous_hi_application', 'previous_hi_application_address', 'city')
        }
      else
        {}
      end
    end

    def previous_sah_application_payload
      if data.dig('previous_sah_application', 'has_previous_sah_application')
        {
          previousSahApplicationDate: data.dig('previous_sah_application', 'previous_sah_application_date'),
          previousSahApplicationAddress: {
            city: data.dig('previous_sah_application', 'previous_sah_application_address', 'city')
          },
          hasPreviousSahApplication: data.dig('previous_sah_application', 'has_previous_sah_application'),
          previousApplicationLocation: data.dig('previous_sah_application', 'previous_sah_application_address',
                                                'city')
        }
      else
        {}
      end
    end

    def veteran_payload
      full_name = data.dig('veteran', 'full_name')
      {
        address: veteran_address_payload,
        ssn: data.dig('veteran', 'ssn')&.tr('-', ''),
        fullName: {
          first: full_name['first']&.[](0..29),
          middle: full_name['middle']&.[](0..29),
          last: full_name['last']&.[](0..29),
          suffix: full_name['suffix']
        },
        homePhone: data.dig('veteran', 'home_phone')&.tr('-', ''),
        mobilePhone: data.dig('veteran', 'mobile_phone')&.tr('-', ''),
        email: data.dig('veteran', 'email'),
        dateOfBirth: data.dig('veteran', 'date_of_birth')
      }
    end

    def veteran_address_payload
      address = data.dig('veteran', 'address')
      if address
        {
          isMilitary: address['is_military'],
          country: address['country'],
          street: address['street'],
          street2: address['street2'],
          city: address['city'],
          state: address['state'],
          postalCode: address['postal_code']
        }
      end
    end

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
