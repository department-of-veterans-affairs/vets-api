# frozen_string_literal: true
require 'rails_helper'
require 'hca/enrollment_system'

describe HCA::EnrollmentSystem do
  describe '#has_financial_flag' do
    [
      {
        data: {
          understandsFinancialDisclosure: true
        },
        return_val: true
      },
      {
        data: {
          discloseFinancialInformation: true
        },
        return_val: true
      },
      {
        data: {
          discloseFinancialInformation: false,
          understandsFinancialDisclosure: false
        },
        return_val: false
      }
    ].each do |test_data|
      context "with data #{test_data[:data]}" do
        it "should return #{test_data[:return_val]} for has_financial_flag" do
          expect(described_class.has_financial_flag(test_data[:data])).to eq(test_data[:return_val])
        end
      end
    end
  end
end
