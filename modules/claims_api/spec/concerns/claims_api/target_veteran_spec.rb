# frozen_string_literal: true

require 'rails_helper'

class FakeTargetController < ApplicationController
  include ClaimsApi::TargetVeteran

  attr_accessor :params, :current_user

  def initialize
    super
    @params = {}
    @current_user = ClaimsApi::ClaimsUser.new('test')
    @current_user.first_name_last_name('John', 'Doe')
    @current_user.middle_name = 'Alexander'
    @current_user.suffix = 'III'
  end

  def token
    @token ||= double('Token', client_credentials_token?: false)
  end
end

describe FakeTargetController do
  let(:controller) { FakeTargetController.new }
  let(:veteran_icn) { '1234567890V123456' }
  let(:mpi_profile) { double('MPI', icn: veteran_icn) }
  let(:target_vet) { double('TargetVeteran', mpi: mpi_profile) }

  describe '#user_is_target_veteran?' do
    before do
      allow(controller.current_user).to receive(:icn).and_return(user_icn)
      controller.params[:veteranId] = params_veteran_id
      allow(controller).to receive(:target_veteran).and_return(target_vet)
    end

    context 'when all conditions are met' do
      let(:user_icn) { veteran_icn }
      let(:params_veteran_id) { veteran_icn }

      it 'returns true' do
        expect(controller.user_is_target_veteran?).to be(true)
      end
    end

    context 'when veteranId param is blank' do
      let(:user_icn) { veteran_icn }
      let(:params_veteran_id) { nil }

      it 'returns false' do
        expect(controller.user_is_target_veteran?).to be(false)
      end
    end

    context 'when current_user icn is blank' do
      let(:user_icn) { nil }
      let(:params_veteran_id) { veteran_icn }

      it 'returns false' do
        expect(controller.user_is_target_veteran?).to be(false)
      end
    end

    context 'when target_veteran mpi icn is blank' do
      let(:user_icn) { veteran_icn }
      let(:params_veteran_id) { veteran_icn }
      let(:mpi_profile) { double('MPI', icn: nil) }

      it 'returns false' do
        expect(controller.user_is_target_veteran?).to be(false)
      end
    end

    context 'when veteranId does not match target_veteran icn' do
      let(:user_icn) { veteran_icn }
      let(:params_veteran_id) { 'different_icn' }

      it 'returns false' do
        expect(controller.user_is_target_veteran?).to be(false)
      end
    end

    context 'when current_user icn does not match target_veteran icn' do
      let(:user_icn) { 'different_icn' }
      let(:params_veteran_id) { veteran_icn }

      it 'returns false' do
        expect(controller.user_is_target_veteran?).to be(false)
      end
    end
  end

  describe '#user_is_representative?' do
    before do
      allow(controller.current_user).to receive_messages(first_name:, last_name:)
      controller.instance_variable_set(:@is_valid_ccg_flow, is_valid_ccg_flow)
    end

    context 'when is_valid_ccg_flow is true' do
      let(:is_valid_ccg_flow) { true }
      let(:first_name) { 'John' }
      let(:last_name) { 'Doe' }

      it 'returns nil' do
        expect(controller.user_is_representative?).to be_nil
      end
    end

    context 'when representative is found' do
      let(:is_valid_ccg_flow) { false }
      let(:first_name) { 'John' }
      let(:last_name) { 'Doe' }
      let(:representative) { double('Representative') }

      before do
        allow(Veteran::Service::Representative).to receive(:find_by).with(first_name,
                                                                          last_name).and_return(representative)
      end

      it 'returns true' do
        expect(controller).to be_user_is_representative
      end
    end

    context 'when representative is not found' do
      let(:is_valid_ccg_flow) { false }
      let(:first_name) { 'John' }
      let(:last_name) { 'Doe' }

      before do
        allow(Veteran::Service::Representative).to receive(:find_by).with(first_name, last_name).and_return(nil)
      end

      it 'returns false' do
        expect(controller).not_to be_user_is_representative
      end
    end
  end

  describe '#target_veteran' do
    let(:veteran_id) { '1234567890V123456' }
    let(:loa) { { current: 3, highest: 3 } }
    let(:built_veteran) { double('ClaimsApi::Veteran') }

    before do
      allow(controller).to receive(:build_target_veteran).and_return(built_veteran)
    end

    context 'when @is_valid_ccg_flow is true' do
      before do
        controller.instance_variable_set(:@is_valid_ccg_flow, true)
        controller.params[:veteranId] = veteran_id
      end

      it 'builds target veteran with veteranId from params and LOA 3' do
        expect(controller).to receive(:build_target_veteran).with(
          veteran_id:,
          loa: { current: 3, highest: 3 }
        )
        controller.target_veteran
      end

      it 'returns the built veteran' do
        expect(controller.target_veteran).to eq(built_veteran)
      end

      it 'memoizes the result' do
        controller.target_veteran
        expect(controller).not_to receive(:build_target_veteran)
        controller.target_veteran
      end
    end

    context 'when @validated_token_payload is present and user has ICN' do
      let(:user_icn) { '9876543210V654321' }

      before do
        controller.instance_variable_set(:@is_valid_ccg_flow, false)
        controller.instance_variable_set(:@validated_token_payload, { 'sub' => 'some_token' })
        allow(controller.current_user).to receive(:icn).and_return(user_icn)
      end

      it 'builds target veteran with current user ICN and LOA 3' do
        expect(controller).to receive(:build_target_veteran).with(
          veteran_id: user_icn,
          loa: { current: 3, highest: 3 }
        )
        controller.target_veteran
      end

      it 'returns the built veteran' do
        expect(controller.target_veteran).to eq(built_veteran)
      end
    end

    context 'when user is a representative' do
      let(:user_loa) { { current: 2, highest: 3 } }

      before do
        controller.instance_variable_set(:@is_valid_ccg_flow, false)
        controller.instance_variable_set(:@validated_token_payload, nil)
        controller.params[:veteranId] = veteran_id
        allow(controller.current_user).to receive(:loa).and_return(user_loa)
        allow(controller).to receive(:user_is_representative?).and_return(true)
      end

      it 'builds target veteran with veteranId from params and user LOA' do
        expect(controller).to receive(:build_target_veteran).with(
          veteran_id:,
          loa: user_loa
        )
        controller.target_veteran
      end

      it 'returns the built veteran' do
        expect(controller.target_veteran).to eq(built_veteran)
      end
    end

    context 'when none of the conditions are met' do
      before do
        controller.instance_variable_set(:@is_valid_ccg_flow, false)
        controller.instance_variable_set(:@validated_token_payload, nil)
        allow(controller).to receive(:user_is_representative?).and_return(false)
      end

      it 'raises Unauthorized exception' do
        expect { controller.target_veteran }.to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end
end
