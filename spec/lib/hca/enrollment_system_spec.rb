# frozen_string_literal: true
require 'rails_helper'
require 'hca/enrollment_system'

describe HCA::EnrollmentSystem do
  describe '#financial_flag?' do
    [
      {
        data: {
          'understandsFinancialDisclosure' => true
        },
        return_val: true
      },
      {
        data: {
          'discloseFinancialInformation' => true
        },
        return_val: true
      },
      {
        data: {
          'discloseFinancialInformation' => false,
          'understandsFinancialDisclosure' => false
        },
        return_val: false
      }
    ].each do |test_data|
      context "with data #{test_data[:data]}" do
        it "should return #{test_data[:return_val]} for has_financial_flag" do
          expect(described_class.financial_flag?(test_data[:data])).to eq(test_data[:return_val])
        end
      end
    end
  end

  describe '#format_zipcode' do
    [
      [
        '12345',
        { 'zipCode' => '12345', 'zipPlus4' => nil }
      ],
      [
        '12345-1234',
        { 'zipCode' => '12345', 'zipPlus4' => '1234' }
      ],
      [
        '12345-123',
        { 'zipCode' => '12345', 'zipPlus4' => nil }
      ]
    ].each do |test_data|
      zipcode = test_data[0]

      context "with a zip of #{zipcode}" do
        it 'should format the zipcode correctly' do
          expect(described_class.format_zipcode(zipcode)).to eq(test_data[1])
        end
      end
    end
  end

  describe '#format_address' do
    let(:test_address) do
      {
        'street' => '123 NW 8th St',
        'street2' =>  '',
        'street3' =>  '',
        'city' => 'Dulles',
        'country' => 'USA',
        'postalCode' => '13AA',
        'provinceCode' => 'ProvinceName',
        'state' => 'VA',
        'zipcode' => '20101-0101'
      }
    end

    it 'should format the address correctly' do
      expect(described_class.format_address(test_address)).to eq(
        'city' => 'Dulles',
        'country' => 'USA',
        'line1' => '123 NW 8th St',
        'state' => 'VA',
        'zipCode' => '20101',
        'zipPlus4' => '0101'
      )
    end

    context 'with a non american address' do
      before do
        test_address['country'] = 'COM'
      end

      it 'should format the address correctly' do
        expect(described_class.format_address(test_address)).to eq(
          'city' => 'Dulles',
          'country' => 'COM',
          'line1' => '123 NW 8th St',
          'provinceCode' => 'VA',
          'postalCode' => '20101-0101'
        )
      end
    end
  end

  describe '#marital_status_to_sds_code' do
    [
      %w(Married M),
      ['Never Married', 'S'],
      %w(Separated A),
      %w(Widowed W),
      %w(Divorced D),
      %w(foo U)
    ].each do |test_data|
      marital_status = test_data[0]
      return_val = test_data[1]

      context "with a marital_status of #{marital_status}" do
        it "should return #{return_val}" do
          expect(described_class.marital_status_to_sds_code(marital_status)).to eq(return_val)
        end
      end
    end
  end
end
