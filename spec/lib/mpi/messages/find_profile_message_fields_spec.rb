# frozen_string_literal: true

require 'spec_helper'
require 'mpi/messages/find_profile_message_fields'

describe MPI::Messages::FindProfileMessageFields do
  describe '.valid?' do
    subject { described_class.new(profile) }

    let(:missing_keys) { %i[given_names last_name birth_date ssn] }

    before do
      subject.validate
    end

    context 'with missing keys and values' do
      let(:profile) { {} }

      its(:valid?) { is_expected.to be(false) }
      its(:missing_keys) { is_expected.to match_array(missing_keys) }
      its(:missing_values) { is_expected.to match_array(missing_keys) }
    end

    context 'with missing values' do
      let(:profile) { { given_names: nil, last_name: '', birth_date: nil, ssn: '' } }

      its(:valid?) { is_expected.to be(false) }
      its(:missing_keys) { is_expected.to be_blank }
      its(:missing_values) { is_expected.to match_array(missing_keys) }
    end

    context 'with required attributes' do
      let(:profile) { { given_names: 'Homer', last_name: 'Simpson', birth_date: '01/01/1972', ssn: '123-45-6789' } }

      its(:valid?) { is_expected.to be(true) }
      its(:missing_keys) { is_expected.to be_blank }
      its(:missing_values) { is_expected.to be_blank }
    end
  end
end
