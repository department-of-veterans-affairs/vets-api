# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)

def basic_class
  PdfFill::Forms::Va210781a.new({})
end

describe PdfFill::Forms::Va210781a do
  let(:form_data) do
    {}
  end
  let(:new_form_class) do
    described_class.new(form_data)
  end
  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end
  # describe '#merge_fields' do
  #   it 'should merge the right fields', run_at: '2016-12-31 00:00:00 EDT' do
  #     expect(described_class.new(get_fixture('pdf_fill/21-0781a/kitchen_sink')).merge_fields).to eq(
  #       get_fixture('pdf_fill/21-0781a/merge_fields')
  #     )
  #   end
  # end

  describe '#expand_ssn' do
    context 'ssn is not blank' do
      let(:form_data) do
        {
          'veteranSocialSecurityNumber' => '123456789'
        }
      end
      it 'should expand the ssn correctly' do
        new_form_class.expand_ssn
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranSocialSecurityNumber' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber1' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber2' => { 'first' => '123', 'second' => '45', 'third' => '6789' }
        )
      end
    end
  end

  describe '#expand_veteran_full_name' do
    context 'contains middle initial' do
      let :form_data do
        {
          'veteranFullName' => {
            'first' => 'Testy',
            'middle' => 'Tester',
            'last' => 'Testerson'
          }
        }
      end
      it 'should expand veteran full name correctly' do
        new_form_class.expand_veteran_full_name
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranFullName' => {
            'first' => 'Testy',
            'middle' => 'Tester',
            'last' => 'Testerson',
            'middleInitial' => 'T'
          }
        )
      end
    end
  end

  describe '#expand_veteran_dob' do
    context 'dob is not blank' do
      let :form_data do
        {
          'veteranDateOfBirth' => '1981-11-05'
        }
      end
      it 'should expand the birth date correctly' do
        new_form_class.expand_veteran_dob
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranDateOfBirth' => {
            'year' => '1981',
            'month' => '11',
            'day' => '05'
          }
        )
      end
    end
  end

  describe '#expand_incident_date' do
    incident = {
      'incidentDate' => '2000-01-01'
    }
    it 'should expand the incident date correctly' do
      expect(new_form_class.expand_incident_date(incident)).to eq(
        'month' => '01',
        'day' => '01',
        'year' => '2000'
      )
    end
  end

  # rubocop:disable Metrics/LineLength
  describe '#expand_incident_location' do
    it 'should expand the incident location into three lines one word each' do
      expect(new_form_class.expand_incident_location(
               'incidentLocation' => 'abcdefghijklmnopqrs xxxxxxxxxxxxxxxxxx zzzzzzzzzzzzzzzzzzz'
      )).to eq(
        'firstRow' => 'abcdefghijklmnopqrs',
        'secondRow' => 'xxxxxxxxxxxxxxxxxx',
        'thirdRow' => 'zzzzzzzzzzzzzzzzzzz'
      )
    end

    it 'should expand the incident location into three lines multiple words' do
      expect(new_form_class.expand_incident_location(
               'incidentLocation' => 'abcd defg hijk lmno pqrs xxxx yyyy zzzz aaaa bb cccc dddd eeee ffff ggg'
      )).to eq(
        'firstRow' => 'abcd defg hijk lmno pqrs xxxx',
        'secondRow' => 'yyyy zzzz aaaa bb cccc dddd',
        'thirdRow' => 'eeee ffff ggg'
      )
    end

    it 'should ignore more than 90 characters' do
      expect(JSON.parse(new_form_class.expand_incident_location(
        'incidentLocation' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
      ).to_json)).to eq(
        'value' => '',
        'extras_value' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
      )
    end
  end
  # rubocop:enable Metrics/LineLength

  describe '#expand incident_unit_assignment' do
    it 'should expand the incident unit assignment into three lines one word each' do
      expect(new_form_class.expand_incident_unit_assignment(
               'unitAssigned' => 'abcdefghijklmnopqrs xxxxxxxxxxxxxxxxxx zzzzzzzzzzzzzzzzzzz'
      )).to eq(
        'firstRow' => 'abcdefghijklmnopqrs',
        'secondRow' => 'xxxxxxxxxxxxxxxxxx',
        'thirdRow' => 'zzzzzzzzzzzzzzzzzzz'
      )
    end

    it 'should expand the incident unit assignment into three lines multiple words' do
      expect(new_form_class.expand_incident_unit_assignment(
               'unitAssigned' => 'abcd defg hijk lmno pqrs xxxx yyyy zzzz aaaa bb cccc dddd eeee ffff ggg'
      )).to eq(
        'firstRow' => 'abcd defg hijk lmno pqrs xxxx',
        'secondRow' => 'yyyy zzzz aaaa bb cccc dddd',
        'thirdRow' => 'eeee ffff ggg'
      )
    end

    it 'should ignore more than 90 characters' do
      expect(JSON.parse(new_form_class.expand_incident_unit_assignment(
        'unitAssigned' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
      ).to_json)).to eq(
        'value' => '',
        'extras_value' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
      )
    end
  end

  describe '#expand_other_sources' do
    it 'should expand sources correctly' do
      incident = {
        'source' => [{
          'name' => {
            'first' => 'Testy',
            'middle' => 'T',
            'last' => 'Testerson'
          },
          'address' => {
            'street' => '123 Main Street',
            'street2' => '1B',
            'city' => 'Baltimore',
            'state' => 'MD',
            'country' => 'USA',
            'postalCode' => '21200-1111'
          }
        }]
      }

      expect(new_form_class.expand_other_sources(incident)).to eq(
        'combinedName0' => 'Testy T Testerson',
        'combinedAddress0' => '123 Main Street, 1B, Baltimore, MD, 21200-1111, USA'
      )
    end

    it 'should expand multiple sources correctly' do
      incident = {
        'source' => [{
          'name' => {
            'first' => 'Testy',
            'middle' => 'T',
            'last' => 'Testerson'
          },
          'address' => {
            'street' => '123 Main Street',
            'street2' => '1B',
            'city' => 'Baltimore',
            'state' => 'MD',
            'country' => 'USA',
            'postalCode' => '21200-1111'
          }
        },
                     {
                       'name' => {
                         'first' => 'Besty',
                         'middle' => 'B',
                         'last' => 'Besterson'
                       },
                       'address' => {
                         'street' => '456 Main Street',
                         'street2' => '1B',
                         'city' => 'Baltimore',
                         'state' => 'MD',
                         'country' => 'USA',
                         'postalCode' => '21200-1111'
                       }
                     }]
      }

      expect(new_form_class.expand_other_sources(incident)).to eq(
        'combinedName0' => 'Testy T Testerson',
        'combinedAddress0' => '123 Main Street, 1B, Baltimore, MD, 21200-1111, USA',
        'combinedName1' => 'Besty B Besterson',
        'combinedAddress1' => '456 Main Street, 1B, Baltimore, MD, 21200-1111, USA'
      )
    end
  end

  # rubocop:disable Metrics/LineLength
  describe '#expand_incidents' do
    it 'incident location should go to overflow' do
      incidents = [{
        'incidentLocation' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234',
        'unitAssigned' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234',
        'unitAssignedDates' => {
          'from' => '2000-01-01',
          'to' => '2005-02-02'
        },
        'source' => [
          {
            'name' => {
              'first' => 'Testy',
              'middle' => 'T',
              'last' => 'Testerson'
            },
            'address' => {
              'street' => '123 Main Street',
              'street2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'postalCode' => '21200-1111'
            }
          },
          {
            'name' => {
              'first' => 'Besty',
              'middle' => 'B',
              'last' => 'Besterson'
            },
            'address' => {
              'street' => '456 Main Street',
              'street2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'postalCode' => '21200-1111'
            }
          },
          {
            'name' => {
              'first' => 'Dusty',
              'middle' => 'D',
              'last' => 'Dusterson'
            },
            'address' => {
              'street' => '789 Main Street',
              'street2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'postalCode' => '21200-1111'
            }
          },
          {
            'name' => {
              'first' => 'Fussy',
              'middle' => 'F',
              'last' => 'Fusserson'
            },
            'address' => {
              'street' => '1111 Main Street',
              'street2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'postalCode' => '21200-1111'
            }
          }
        ]
      }]

      expect(JSON.parse(new_form_class.expand_incidents(incidents).to_json)).to eq(
        [{
          'incidentLocation' => {
            'incidentLocationOverflow' => {
              'value' => '',
              'extras_value' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
            }
          },
          'unitAssigned' => {
            'unitAssignedOverflow' => {
              'value' => '',
              'extras_value' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
            }
          },
          'unitAssignedDates' => {
            'fromMonth' => '01',
            'fromDay' => '01',
            'fromYear' => '2000',
            'toMonth' => '02',
            'toDay' => '02',
            'toYear' => '2005'
          },
          'source' => {
            'sourceOverflow' => {
              'value' => '',
              'extras_value' => 'Testy T Testerson\n123 Main Street, 1B, Baltimore, MD, 21200-1111, USA\n\nBesty B Besterson\n456 Main Street, 1B, Baltimore, MD, 21200-1111, USA\n\nDusty D Dusterson\n789 Main Street, 1B, Baltimore, MD, 21200-1111, USA\n\nFussy F Fusserson\n1111 Main Street, 1B, Baltimore, MD, 21200-1111, USA'
            }
          }
        }]
      )
    end
  end
  # rubocop:enable Metrics/LineLength
end
