# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'In Progress Forms - FSR (5655)' do
  let(:user_loa3) { build(:user, :loa3) }

  def with_vcr(payments_vcr, &block)
    VCR.use_cassette('evss/pciu/email') do
      VCR.use_cassette('evss/pciu/primary_phone') do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette(payments_vcr) do
            block.call
          end
        end
      end
    end
  end

  describe '/v0/in_progress_forms/5655' do
    let(:endpoint) { '/v0/in_progress_forms/5655' }

    before { sign_in_as(user_loa3) }

    context 'with payments' do
      context 'with posted payments only' do
        let(:expected_payments) { [{ 'veteranOrSpouse' => 'VETERAN', 'compensationAndPension' => '3444.7' }] }

        it 'returns a pre-filled form' do
          with_vcr('bgs/payment_service/payment_history') do
            get endpoint
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['formData']['income']).to eq(expected_payments)
          end
        end
      end

      context 'with posted and pending payments' do
        let(:expected_payments) { [{ 'veteranOrSpouse' => 'VETERAN', 'compensationAndPension' => '8888.88' }] }

        it 'returns a pre-filled form' do
          with_vcr('bgs/payment_service/payment_history_with_pending') do
            get endpoint
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['formData']['income']).to eq(expected_payments)
          end
        end
      end
    end
  end
end
