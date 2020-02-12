# frozen_string_literal: true

require 'rails_helper'

describe MDOT::Client do
  subject { described_class.new(user) }

  let(:user_details) do
    {
      first_name: 'Greg',
      last_name: 'Anderson',
      middle_name: 'A',
      birth_date: '1949-03-04',
      ssn: '000555555'
    }
  end

  let(:user) { build(:user, :loa3, user_details) }

  describe '#get_supplies' do
    context 'with a valid supplies response' do
      it 'returns an array of supplies' do
        VCR.use_cassette('mdot/get_supplies_200') do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
        end
      end
    end
  end

  describe '#submit_order' do
    context 'with a valid supplies order' do
      it 'returns a successful response' do
        VCR.use_cassette('mdot/submit_order_202') do
          order = {
            veteranFullName: {
              first: 'Greg',
              middle: 'A',
              last: 'Anderson'
            },
            veteranAddress: {
              street: '101 Example Street',
              street2: 'Apt 2',
              city: 'Kansas City',
              state: 'MO',
              country: 'USA',
              postalCode: '64117'
            },
            order: [
              {
                productId: 1
              },
              {
                productId: 4
              }
            ],
            additionalRequests: ''
          }.to_json

          response = subject.submit_order(order)
          expect(response).to be_accepted
          expect(response).to be_an MDOT::Response
        end
      end
    end
  end
end
