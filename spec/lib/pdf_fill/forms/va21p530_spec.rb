# frozen_string_literal: true
require 'rails_helper'
require 'pdf_fill/forms/va21p530'


def basic_class
  PdfFill::Forms::VA21P530.new({})
end

describe PdfFill::Forms::VA21P530 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  test_method(
    basic_class,
    'expand_relationship',
    [
      [
        [{}, nil],
        nil
      ],
      [
        [
          {
            rel: {
              'type' => 'foo'
            }
          },
          :rel
        ],
        {"foo"=>true}
      ]
    ]
  )

  test_method(
    basic_class,
    'expand_tours_of_duty',
    [
      [
        [nil],
        nil
      ],
      [
        [[{
          "dateRange" => {
            "from" => "2012-06-01",
            "to" => "2013-07-01"
          },
          "serviceBranch" => "army1",
          "rank" => "rank1",
          "serviceNumber" => "sn1",
          "placeOfEntry" => "placeOfEntry1",
          "placeOfSeparation" => "place1"
        }]],
        [{"serviceBranch"=>"army1",
          "rank"=>"army1, rank1",
          "serviceNumber"=>"sn1",
          "placeOfEntry"=>"placeOfEntry1",
          "placeOfSeparation"=>"place1",
          "dateRangeStart"=>"2012-06-01",
          "dateRangeEnd"=>"2013-07-01"}]
      ]
    ]
  )

  test_method(
    basic_class,
    'split_phone',
    [
      [
        [{}, nil],
        nil
      ],
      [
        [
          { phone: '1112223333' },
          :phone
        ],
        {"first"=>"111", "second"=>"222", "third"=>"3333"}
      ]
    ]
  )

  describe '#expand_place_of_death' do
    subject do
      new_form_class.expand_place_of_death
    end

    context 'with no location of death' do
      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with a regular location of death' do
      let(:form_data) do
        {
          "locationOfDeath" => {
            "location" => "vaMedicalCenter"
          }
        }
      end

      it 'should return the translated location' do
        expect(subject).to eq('VA MEDICAL CENTER')
      end
    end

    context 'with a custom location of death' do
      let(:form_data) do
        {
          "locationOfDeath" => {
            "location" => "other",
            "other" => 'foo'
          }
        }
      end

      it 'should return the translated location' do
        expect(subject).to eq('foo')
      end
    end
  end

  describe '#split_ssn' do
    subject do
      new_form_class.split_ssn
    end

    context 'with no ssn' do
      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with a ssn' do
      let(:form_data) do
        {
          'veteranSocialSecurityNumber' => '111223333'
        }
      end

      it 'should split the ssn' do
        expect(subject).to eq({"first"=>"111", "second"=>"22", "third"=>"3333"})
      end
    end
  end

  describe '#extract_middle_i' do
    subject do
      described_class.new(form_data).extract_middle_i(form_data, 'veteranFullName')
    end

    context 'with no veteran full name' do
      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with no middle name' do
      let(:form_data) do
        {
          'veteranFullName' => {}
        }
      end

      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with a middle name' do
      let(:form_data) do
        {
          'veteranFullName' => {
            'middle' => 'middle'
          }
        }
      end

      it 'should extract middle initial' do
        expect(subject).to eq({
          'middle' => 'middle',
          'middleInitial' => 'm'
        })
      end
    end
  end
end
