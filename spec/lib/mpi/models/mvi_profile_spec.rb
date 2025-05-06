# frozen_string_literal: true

require 'rails_helper'

describe MPI::Models::MviProfile do
  describe '#mhv_correlation_id' do
    context 'with multiple ids' do
      subject { build(:mpi_profile) }

      it 'returns the first id' do
        expect(subject.mhv_correlation_id).to eq(subject.mhv_ids.first)
      end
    end

    context 'with a single id' do
      subject { build(:mpi_profile, mhv_ids: [id]) }

      let(:id) { '12345678' }

      it 'returns the id' do
        expect(subject.mhv_correlation_id).to eq(id)
      end
    end

    context 'with no ids' do
      subject { build(:mpi_profile, mhv_ids: nil) }

      it 'returns nil' do
        expect(subject.mhv_correlation_id).to be_nil
      end
    end

    context 'with an invalid birth date' do
      subject { build(:mpi_profile, birth_date: '0') }

      it 'returns a nil birth_date' do
        expect(subject.birth_date).to be_nil
      end
    end

    context 'with a valid birth date' do
      subject { build(:mpi_profile, birth_date: '1985-01-01') }

      it 'returns a non-nil birth_date' do
        expect(Date.parse(subject.birth_date)).to be_a(Date)
        expect(subject.birth_date).not_to be_nil
      end
    end
  end

  describe '#normalized_suffix' do
    context 'with a non-nil suffix' do
      cases = {
        'Jr.' => %w[jr jr. JR JR. Jr Jr. jR jR.],
        'Sr.' => %w[sr sr. SR SR. Sr Sr. sR sR.],
        'II' => %w[i I].repeated_permutation(2).map(&:join),
        'III' => %w[i I].repeated_permutation(3).map(&:join),
        'IV' => %w[iv IV Iv iV],
        nil => %w[i mr ms mrs md v]
      }

      cases.each do |expected_result, inputs|
        inputs.each do |input|
          it 'returns a properly formatted suffix' do
            expect(build(:mpi_profile, suffix: input).normalized_suffix).to eq(expected_result)
          end
        end
      end
    end
  end

  describe 'attributes' do
    subject { build(:mpi_profile) }

    it 'returns a icn_with_aaid' do
      expect(subject.icn_with_aaid.present?).to be true
    end
  end
end
