# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::Veteran, type: :model do
  let(:user_account) { create(:user_account, icn: icn) }
  let(:icn) { nil }
  let(:in_progress_form) { create(:in_progress_686c_form, user_account: user_account) }
  let(:subject) { VANotify::Veteran.new(in_progress_form) }

  describe '#first_name' do
    context 'unsupported form id' do
      let(:in_progress_form) { create(:in_progress_1010ez_form, user_account: user_account, form_id: 'something') }

      it 'raises error with unsupported form id' do
        expect { subject.first_name }.to raise_error(VANotify::Veteran::UnsupportedForm)
      end
    end

    context '686c' do
      it 'returns the first_name from form data' do
        expect(subject.first_name).to eq('first_name')
      end
    end

    context '1010ez' do
      let(:in_progress_form) { create(:in_progress_1010ez_form, user_account: user_account) }

      it 'returns the first_name from form data' do
        expect(subject.first_name).to eq('first_name')
      end
    end

    context '526ez' do
      let(:icn) { 'icn' }
      let(:in_progress_form) { create(:in_progress_526_form, user_account: user_account) }

      it 'returns the first_name from mpi' do
        mpi_double = double('MPI::Service')
        allow(MPI::Service).to receive(:new).and_return(mpi_double)
        mpi_response_double = double('MPI::Responses::FindProfileResponse', ok?: true)
        allow(mpi_double).to receive(:find_profile).with(subject).and_return(mpi_response_double)

        mpi_profile = build(:mvi_profile, given_names: ['first_name'])
        allow(mpi_response_double).to receive(:profile).and_return(mpi_profile)

        expect(subject.first_name).to eq('first_name')
      end

      it 'raises an error if MPI returns a not #ok? response' do
        mpi_double = double('MPI::Service')
        allow(MPI::Service).to receive(:new).and_return(mpi_double)
        mpi_response_double = double('MPI::Responses::FindProfileResponse', ok?: false)
        allow(mpi_double).to receive(:find_profile).with(subject).and_return(mpi_response_double)

        expect { subject.first_name }.to raise_error(VANotify::Veteran::MPIError)
      end

      it 'raises an error if MPI profile given name is empty' do
        mpi_double = double('MPI::Service')
        allow(MPI::Service).to receive(:new).and_return(mpi_double)
        mpi_response_double = double('MPI::Responses::FindProfileResponse', ok?: true)
        allow(mpi_double).to receive(:find_profile).with(subject).and_return(mpi_response_double)

        mpi_profile = build(:mvi_profile, given_names: nil)
        allow(mpi_response_double).to receive(:profile).and_return(mpi_profile)

        expect { subject.first_name }.to raise_error(VANotify::Veteran::MPINameError)
      end
    end
  end

  it '#user_uuid, #uuid' do
    expect(subject.user_uuid).to eq(in_progress_form.user_uuid)
    expect(subject.uuid).to eq(in_progress_form.user_uuid)
  end

  describe '#verified, loa3?' do
    context 'with icn' do
      let(:icn) { 'icn' }

      it 'returns the icn associated to the user account associated to the in_progress_form if it exists' do
        expect(subject.verified?).to be(true)
        expect(subject.loa3?).to be(true)
      end
    end

    context 'without associated account' do
      let(:user_account) { nil }

      it 'returns nil if no matching account is found' do
        expect(subject.verified?).to be(false)
        expect(subject.loa3?).to be(false)
      end
    end

    context 'without icn' do
      let(:icn) { nil }

      it 'returns nil if no icn is found' do
        expect(subject.verified?).to be(false)
        expect(subject.loa3?).to be(false)
      end
    end
  end

  describe '#icn' do
    context 'with icn' do
      let(:icn) { 'icn' }

      it 'returns the icn associated to the user account associated to the in_progress_form if it exists' do
        expect(subject.icn).to eq('icn')
      end
    end

    context 'without associated account' do
      let(:user_account) { nil }

      it 'returns nil if no matching account is found' do
        expect(subject.icn).to eq(nil)
      end
    end

    context 'without icn' do
      let(:icn) { nil }

      it 'returns nil if no icn is found' do
        expect(subject.icn).to eq(nil)
      end
    end
  end

  it '#authn_context' do
    expect(subject.authn_context).to eq('va_notify_lookup')
  end
end
