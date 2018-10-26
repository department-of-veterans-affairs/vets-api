# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

def basic_class
  PdfFill::Forms::Va210781a.new({})
end

describe PdfFill::Forms::Va210781 do
  let(:form_data) do
    {}
  end
  let(:new_form_class) do
    described_class.new(form_data)
  end
  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end
  describe '#merge_fields' do
    it 'should merge the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/21-0781/simple')).merge_fields).to eq(
        get_fixture('pdf_fill/21-0781/merge_fields')
      )
    end
  end

  describe '#expand_ssn' do
    context 'ssn is not blank' do
      let(:form_data) do
        {
          'veteranSocialSecurityNumber' => '123456789'
        }
      end
      it 'should expand the ssn correctly' do
        new_form_class.send(:expand_ssn)
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
        new_form_class.send(:expand_veteran_full_name)
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
        new_form_class.send(:expand_veteran_dob)
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
      expect(new_form_class.send(:expand_incident_date, incident)).to eq(
        'month' => '01',
        'day' => '01',
        'year' => '2000'
      )
    end
  end

  # rubocop:disable Metrics/LineLength
  describe '#expand_incident_location' do
    it 'should expand the incident location into three lines one word each' do
      expect(new_form_class.send(:expand_incident_location,
                                 'incidentLocation' => 'abcdefghijklmnopqrs xxxxxxxxxxxxxxxxxx zzzzzzzzzzzzzzzzzzz')).to eq(
                                   'row0' => 'abcdefghijklmnopqrs',
                                   'row1' => 'xxxxxxxxxxxxxxxxxx',
                                   'row2' => 'zzzzzzzzzzzzzzzzzzz'
                                 )
    end

    it 'should ignore more than 90 characters' do
      expect(JSON.parse(new_form_class.send(:expand_incident_location,
                                            'incidentLocation' => 'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234').to_json)).to eq(
                                              'row0' => 'abcdefghijklmno',
                                              'row1' => 'pqrstuvwxyz1234 abcdefghinopq',
                                              'row2' => 'rstuvwxyz1234',
                                              'row3' => 'abcdefghijklmnopqrst',
                                              'row4' => 'uvwxyz1234'
                                            )
    end
  end

  describe '#expand incident_unit_assignment' do
    it 'should expand the incident unit assignment into three lines one word each' do
      expect(new_form_class.send(:expand_incident_unit_assignment,
                                 'unitAssigned' => 'abcdefghijklmnopqrs xxxxxxxxxxxxxxxxxx zzzzzzzzzzzzzzzzzzz')).to eq(
                                   'row0' => 'abcdefghijklmnopqrs',
                                   'row1' => 'xxxxxxxxxxxxxxxxxx',
                                   'row2' => 'zzzzzzzzzzzzzzzzzzz'
                                 )
    end

    it 'should expand the incident unit assignment into three lines multiple words' do
      expect(new_form_class.send(:expand_incident_unit_assignment,
                                 'unitAssigned' =>
                                 'abcd defg hijk lmno pqrs xxxx yyyy zzzz aaaa bb cccc dddd eeee ffff ggg')).to eq(
                                   'row0' => 'abcd defg hijk lmno pqrs xxxx',
                                   'row1' => 'yyyy zzzz aaaa bb cccc dddd',
                                   'row2' => 'eeee ffff ggg'
                                 )
    end

    it 'should ignore more than 90 characters' do
      expect(JSON.parse(new_form_class.send(
        :expand_incident_unit_assignment,
        'unitAssigned' =>
        'abcdefghijklmno pqrstuvwxyz1234 abcdefghinopq rstuvwxyz1234 abcdefghijklmnopqrst uvwxyz1234'
      ).to_json)).to eq(
        'row0' => 'abcdefghijklmno',
        'row1' => 'pqrstuvwxyz1234 abcdefghinopq',
        'row2' => 'rstuvwxyz1234',
        'row3' => 'abcdefghijklmnopqrst',
        'row4' => 'uvwxyz1234'
      )
    end
  end
  # rubocop:enable Metrics/LineLength
end
