# frozen_string_literal: true

require 'rails_helper'

class FakeController < ApplicationController
  include ClaimsApi::PoaVerification

  def initialize
    super
    @current_user = ClaimsApi::ClaimsUser.new('test')
    @current_user.first_name_last_name('John', 'Doe')
    @current_user.middle_name = 'Alexander'
    @current_user.suffix = 'III'
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
        expect(ret).to be(false)
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
          expect(ret).to be(true)
        end
      end

      context 'when the poa_code does not match' do
        before do
          create(:representative, representative_id: '12345', first_name:, last_name:,
                                  poa_codes: ['ABC'], phone:)
        end

        it 'returns false' do
          ret = subject.valid_poa_code_for_current_user?(poa_code)
          expect(ret).to be(false)
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
        expect(res).to be(true)
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
          expect(res).to be(true)
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
          expect do
            subject.valid_poa_code_for_current_user?(poa_code)
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the repʼs last name includes a suffix that matches the current userʼs suffix' do
      before do
        create(:representative, representative_id: '12345', first_name:, last_name: "#{last_name} III",
                                poa_codes: ['091'], phone:)
      end

      it 'finds the rep and returns true' do
        res = subject.valid_poa_code_for_current_user?(poa_code)
        expect(res).to be(true)
      end
    end

    context 'logging in exactly_one_rep_match?' do
      context 'when called via find_by_poa_code' do
        before do
          # Set up expectations for first/last name lookup to fail, so we reach find_by_poa_code
          allow(Veteran::Service::Representative).to receive(:all_for_user).with(
            first_name:,
            last_name:
          ).and_return([])

          # Return empty for suffix

          # Mock the middle_name and middle_initial search to return empty
          allow(subject.instance_variable_get(:@current_user)).to receive_messages(suffix: nil,
                                                                                   middle_name: 'Alexander')
          allow(Veteran::Service::Representative).to receive(:all_for_user).with(
            first_name:,
            last_name:,
            middle_initial: 'A'
          ).and_return([])
        end

        it 'logs when exactly one rep is found' do
          # Create a rep with the matching POA code
          rep = create(:representative, representative_id: '12345', first_name:,
                                        last_name:, poa_codes: [poa_code])

          allow(Veteran::Service::Representative).to receive(:all_for_user).with(
            first_name:,
            last_name:,
            poa_code:
          ).and_return([rep])

          expect(ClaimsApi::Logger).to receive(:log).with(
            'poa_verification',
            rep_method: 'find_by_poa_code',
            details: "Found 1 reps for POA code #{poa_code}"
          )

          # Call the method
          result = subject.valid_poa_code_for_current_user?(poa_code)
          expect(result).to be(true)
        end
      end
    end
  end
end
