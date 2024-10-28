# frozen_string_literal: true

require 'rails_helper'

class FakeController < ApplicationController
  include ClaimsApi::PoaVerification

  def initialize
    super
    @current_user = ClaimsApi::ClaimsUser.new('test')
    @current_user.first_name_last_name('John', 'Doe')
    @current_user.middle_name = 'Alexander'
  end
end

describe FakeController do
  context 'validating poa_code for current_user' do
    let(:poa_code) { '091' }
    let(:first_name) { 'John' }
    let(:last_name) { 'Doe' }
    let(:phone) { '123-456-7890' }

    context 'when no rep is found' do
      it 'returns false' do
        ret = subject.valid_poa_code_for_current_user?(poa_code)
        expect(ret).to eq(false)
      end
    end

    context 'when a single match is found by first/last name' do
      context 'when the poa_code matches' do
        before do
          create(:representative, representative_id: '12345', first_name:, last_name:,
                                  poa_codes: [poa_code], phone:)
        end

        it 'returns true' do
          ret = subject.valid_poa_code_for_current_user?(poa_code)
          expect(ret).to eq(true)
        end
      end

      context 'when the poa_code does not match' do
        before do
          create(:representative, representative_id: '12345', first_name:, last_name:,
                                  poa_codes: ['ABC'], phone:)
        end

        it 'returns false' do
          ret = subject.valid_poa_code_for_current_user?(poa_code)
          expect(ret).to eq(false)
        end
      end
    end

    context 'when there is a suffix' do
      context 'and the poa_code matches' do
        let(:user) do
          ClaimsApi::ClaimsUser.new('test')
        end

        before do
          user.suffix = 'Jr'
          user.first_name = 'Sam'
          user.last_name = 'Smith'
          FakeController.instance_variable_set(:@current_user, user)
          FactoryBot.create(:representative, first_name: 'Sam', last_name: 'Smith Jr')
        end

        xit 'returns true', reason: 'wip' do # rubocop:disable RSpec/PendingWithoutReason
          # allow_any_instance_of(ClaimsApi::PoaVerification).to receive(user).and_return(@current_user)
          ret = subject.valid_poa_code_for_current_user?(poa_code)
          expect(ret).to eq(true)
        end
      end
    end

    context 'when multiple matches are found by first/last name' do
      before do
        create(:representative, representative_id: '12345', first_name:, last_name:,
                                middle_initial: 'A', poa_codes: ['091'], phone:)
        create(:representative, representative_id: '123456', first_name:, last_name:,
                                middle_initial: 'B', poa_codes: ['091'], phone:)
      end

      it 'searches with middle name' do
        res = subject.valid_poa_code_for_current_user?(poa_code)
        expect(res).to eq(true)
      end
    end

    context 'when multiple matches are found by first/last/middle name' do
      context 'when a single rep is found' do
        before do
          create(:representative, representative_id: '12345', first_name:, last_name:,
                                  middle_initial: 'A', poa_codes: ['ABC'], phone:)
          create(:representative, representative_id: '123456', first_name:, last_name:,
                                  middle_initial: 'B', poa_codes: ['DEF'], phone:)
          create(:representative, representative_id: '1234567', first_name:, last_name:,
                                  middle_initial: 'A', poa_codes: ['091'], phone:)
        end

        it 'returns true' do
          res = subject.valid_poa_code_for_current_user?(poa_code)
          expect(res).to eq(true)
        end
      end

      context 'when multiple reps are found' do
        before do
          create(:representative, representative_id: '12345', first_name:, last_name:,
                                  middle_initial: 'A', poa_codes: ['091'], phone:)
          create(:representative, representative_id: '123456', first_name:, last_name:,
                                  middle_initial: 'B', poa_codes: ['091'], phone:)
          create(:representative, representative_id: '1234567', first_name:, last_name:,
                                  middle_initial: 'A', poa_codes: ['091'], phone:)
        end

        it 'raises "Ambiguous VSO Representative Results"' do
          expect { subject.valid_poa_code_for_current_user?(poa_code) }.to raise_error(Common::Exceptions::Unauthorized)
        end
      end
    end
  end
end
