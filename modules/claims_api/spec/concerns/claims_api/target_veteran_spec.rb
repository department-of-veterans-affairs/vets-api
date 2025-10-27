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
end
