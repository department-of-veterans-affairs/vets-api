# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::StagingData::Build do
  describe '#dump' do
    let(:target) { double('Pathname (Target)') }

    let(:source) { double('Pathname (Source)') }

    let(:paths) do
      {
        test_users: Vye::Engine.root / 'spec/fixtures/fake_staging_sample/test_users.csv',
        mvi_staging_users: Vye::Engine.root / 'spec/fixtures/fake_staging_sample/mvi-staging-users.csv'
      }.freeze
    end

    let(:staging_data_build) do
      Vye::StagingData::Build.new(source:, target:).tap do |build|
        allow(build).to receive(:paths).and_return(paths)
      end
    end

    it 'returns an array of rows' do
      root = double('Pathname (Root)')
      dump_file = double('Pathname (File)')

      expect(target).to receive(:/).and_return(root)
      expect(root).to receive(:mkpath).with(no_args).and_return(true)
      expect(root).to receive(:/).twice.with(any_args).and_return(dump_file)
      expect(dump_file).to receive(:write).twice.and_return(true)

      staging_data_build.dump
    end
  end
end
