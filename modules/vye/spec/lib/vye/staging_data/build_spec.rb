# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::StagingData::Build do
  describe '#dump' do
    let(:target) { double('Pathname (Target)') }

    let(:source) { double('Pathname (Source)') }

    let(:streams) do
      {
        test_users: StringIO.new(<<~TEST_USERS),
          first_name,middle_name,last_name,gender,birth_date,ssn,phone,email,password,mfa_code,id_types,loa,idme_uuid,logingov_uuid,services,notes
          John,A,Doe,M,1932-02-05T00:00:00-08:00,111111111,800-827-1000,user1@email.com,xxx,xxx,"idme,logingov",3,xxx,xxx,"notes",
          Jane,B,Smith,M,1933-04-05T00:00:00-08:00,222222222,800-827-1000,user2@email.com,xxx,xxx,"idme,logingov",3,xxx,xxx,"notes",
        TEST_USERS
        mvi_staging_users: StringIO.new(<<~MVI_STAGING_USERS)
          first_name,middle_name,last_name,gender,birth_date,ssn,phone,email,password,icn,edipi,has_data_for, notes
          John,A,Doe,M,1932-02-05T00:00:00-08:00,111111111,800-827-1000,user1@email.com,xxx,xxx,xxx,,notes
          Jane,B,Smith,M,1933-04-05T00:00:00-08:00,222222222,800-827-1000,user2@email.com,xxx,xxx,xxx,,
        MVI_STAGING_USERS
      }.freeze
    end

    let(:staging_data_build) do
      Vye::StagingData::Build.new(target:) do |_paths|
        streams
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
