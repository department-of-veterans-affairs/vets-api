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
end
