# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/common_ptsd'

describe PdfFill::Forms::CommonPtsd do
  let(:including_class) { Class.new { include PdfFill::Forms::CommonPtsd } }

  describe '#expand_ssn' do
    it 'expands the ssn correctly' do
      expect(
        JSON.parse(including_class.new.expand_ssn('veteranSocialSecurityNumber' => '123456789').to_json)
      ).to eq(
        'veteranSocialSecurityNumber' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
        'veteranSocialSecurityNumber1' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
        'veteranSocialSecurityNumber2' => { 'first' => '123', 'second' => '45', 'third' => '6789' }
      )
    end
  end

  describe '#expand_veteran_dob' do
    it 'expands the birth date correctly' do
      expect(
        JSON.parse(including_class.new.expand_veteran_dob(
          'veteranDateOfBirth' => '1981-11-05'
        ).to_json)
      ).to eq(
        'year' => '1981',
        'month' => '11',
        'day' => '05'
      )
    end
  end

  describe '#expand_incident_location' do
    it 'expands the incident location into three lines one word each' do
      expect(including_class.new.expand_incident_location(
               'incidentLocation' => 'abcdefghijklmnopqrs xxxxxxxxxxxxxxxxxx zzzzzzzzzzzzzzzzzzz'
             )).to eq(
               'row0' => 'abcdefghijklmnopqrs',
               'row1' => 'xxxxxxxxxxxxxxxxxx',
               'row2' => 'zzzzzzzzzzzzzzzzzzz'
             )
    end

    it 'expands the incident location into three lines multiple words' do
      expect(including_class.new.expand_incident_location(
               'incidentLocation' => 'abcd defg hijk lmno pqrs xxxx yyyy zzzz aaaa bb cccc dddd eeee ffff ggg'
             )).to eq(
               'row0' => 'abcd defg hijk lmno pqrs xxxx',
               'row1' => 'yyyy zzzz aaaa bb cccc dddd',
               'row2' => 'eeee ffff ggg'
             )
    end

    it 'ignores more than 90 characters' do
      expect(JSON.parse(including_class.new.expand_incident_location(
        'incidentLocation' =>
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

  describe '#expand incident_unit_assignment' do
    it 'expands the incident unit assignment into three lines one word each' do
      expect(including_class.new.expand_incident_unit_assignment(
               'unitAssigned' => 'abcdefghijklmnopqrs xxxxxxxxxxxxxxxxxx zzzzzzzzzzzzzzzzzzz'
             )).to eq(
               'row0' => 'abcdefghijklmnopqrs',
               'row1' => 'xxxxxxxxxxxxxxxxxx',
               'row2' => 'zzzzzzzzzzzzzzzzzzz'
             )
    end

    it 'expands the incident unit assignment into three lines multiple words' do
      expect(including_class.new.expand_incident_unit_assignment(
               'unitAssigned' =>
               'abcd defg hijk lmno pqrs xxxx yyyy zzzz aaaa bb cccc dddd eeee ffff ggg'
             )).to eq(
               'row0' => 'abcd defg hijk lmno pqrs xxxx',
               'row1' => 'yyyy zzzz aaaa bb cccc dddd',
               'row2' => 'eeee ffff ggg'
             )
    end

    it 'ignores more than 90 characters' do
      expect(JSON.parse(including_class.new.expand_incident_unit_assignment(
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

  describe '#expand_incident_date' do
    it 'expands the incident date correctly' do
      expect(including_class.new.expand_incident_date('incidentDate' => '2000-01-01')).to eq(
        'month' => '01',
        'day' => '01',
        'year' => '2000'
      )
    end
  end

  describe '#split_approximate_date' do
    context 'when there is a full date' do
      let(:date) { '2099-12-01' }

      it 'returns the year, month, and day' do
        expect(including_class.new.split_approximate_date(date)).to include(
          'year' => '2099',
          'month' => '12',
          'day' => '01'
        )
      end
    end

    context 'when there is a partial date (year and month)' do
      let(:date) { '2099-12-XX' }

      it 'returns the year and month' do
        expect(including_class.new.split_approximate_date(date)).to include(
          'year' => '2099',
          'month' => '12'
        )
      end
    end

    context 'when there is a partial date (year only)' do
      let(:date) { '2099-XX-XX' }

      it 'returns the year' do
        expect(including_class.new.split_approximate_date(date)).to include(
          'year' => '2099'
        )
      end
    end

    context 'when there is no year' do
      let(:date) { 'XXXX-01-31' }

      it 'returns the year' do
        expect(including_class.new.split_approximate_date(date)).to include(
          'month' => '01',
          'day' => '31'
        )
      end
    end
  end
end
