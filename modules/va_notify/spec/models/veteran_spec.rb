# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::Veteran, type: :model do
  let(:user_account) { create(:user_account, icn:) }
  let(:icn) { nil }
  let(:in_progress_form) { create(:in_progress_686c_form, user_account:) }
  let(:subject) { VANotify::Veteran.new(in_progress_form) }

  describe '#first_name' do
    context 'unsupported form id' do
      let(:in_progress_form) { create(:in_progress_1010ez_form, user_account:, form_id: 'something') }

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
      let(:in_progress_form) { create(:in_progress_1010ez_form, user_account:) }

      it 'returns the first_name from form data' do
        expect(subject.first_name).to eq('first_name')
      end
    end

    context '526ez' do
      let(:icn) { 'icn' }
      let(:in_progress_form) { create(:in_progress_526_form, user_account:) }
      let(:mpi_response) { create(:find_profile_response, profile: build(:mpi_profile, given_names: [first_name])) }

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
          .with(identifier: icn, identifier_type: MPI::Constants::ICN).and_return(mpi_response)
      end

      context 'when first name from MPI exists' do
        let(:first_name) { 'some-first-name' }

        it 'returns the first_name from mpi' do
          expect(subject.first_name).to eq(first_name)
        end
      end

      context 'with invalid MPI response' do
        let(:mpi_response) { create(:find_profile_not_found_response) }

        it 'raises an error' do
          expect { subject.first_name }.to raise_error(VANotify::Veteran::MPIError)
        end
      end

      context 'when first name from MPI does not exist' do
        let(:first_name) { nil }

        it 'raises an error' do
          expect { subject.first_name }.to raise_error(VANotify::Veteran::MPINameError)
        end
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
