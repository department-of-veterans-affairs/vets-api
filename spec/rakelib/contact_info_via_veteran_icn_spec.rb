# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'contact info via veteran icn task', type: :request do
  let(:user) { build(:disabilities_compensation_user) }
  let(:expected_csv) do
  end
  let(:icn1) { 'test-icn-1' }
  let(:icn2) { 'test-icn-2' }
  let(:icn3) { 'test-icn-3' }

  let(:vet360_id1) { 'test-vet360-id1' }
  let(:vet360_id2) { 'test-vet360-id2' }
  let(:vet360_id3) { 'test-vet360-id3' }

  let(:mpi_profile1) { build(:mpi_profile, icn: icn1, vet360_id: vet360_id1) }
  let(:mpi_profile2) { build(:mpi_profile, icn: icn2, vet360_id: vet360_id2) }
  let(:mpi_profile3) do
    profile = build(:mpi_profile, icn: icn3, vet360_id: vet360_id3)
    profile.address.street2 = 'Apt A'
    profile
  end

  let(:vet360_profile1) { build(:person, vet360_id: vet360_id1) }
  let(:vet360_profile2) do
    profile = build(:person, vet360_id: vet360_id2)
    retired_email = FactoryBot.build(:email, effective_end_date: Time.zone.today.prev_month)
    profile.emails << retired_email
    profile
  end
  let(:vet360_profile3) { build(:person, vet360_id: vet360_id3) }

  let(:bgs_person1) do
    { file_nbr: 'test-file-number-1' }
  end
  let(:bgs_person2) do
    { file_nbr: 'test-file-number-2' }
  end
  let(:bgs_person3) do
    { file_nbr: '123-45-6789' }
  end

  let(:expected_result1) do
    address = mpi_profile1.address
    [
      icn1, bgs_person1[:file_nbr], vet360_profile1.emails.first.email_address,
      "#{address.street}, #{address.city} #{address.postal_code}, #{address.country}"
    ]
  end

  let(:expected_result2) do
    address = mpi_profile2.address
    active_email = vet360_profile2.emails.select { |email| email.effective_end_date.nil? }.first
    [
      icn2, bgs_person2[:file_nbr], active_email.email_address,
      "#{address.street}, #{address.city} #{address.postal_code}, #{address.country}"
    ]
  end

  let(:expected_result3) do
    address = mpi_profile3.address
    file_number = bgs_person3[:file_nbr].delete('-')
    [
      icn3, file_number, vet360_profile3.emails.first.email_address,
      "#{address.street}, #{address.street2}, #{address.city} #{address.postal_code}, #{address.country}"
    ]
  end

  let(:csv_filename) { 'contact_info_rake_task_output.csv' }
  let(:path_to_csv) { "tmp/#{csv_filename}" }

  before :all do
    Rake.application.rake_require '../rakelib/contact_info_via_veteran_icn'
    Rake::Task.define_task(:environment)
  end

  after do
    File.delete(path_to_csv)
  end

  describe 'rake veteran_contact_info:build_contact_info_csv' do
    let(:icn_list) { "#{icn1} #{icn2} #{icn3}" }
    let :run_rake_task do
      Rake::Task['veteran_contact_info:build_contact_info_csv'].reenable
      Rake.application.invoke_task "veteran_contact_info:build_contact_info_csv[#{csv_filename}, #{icn_list}]"
    end

    it 'generates a csv with expected values' do
      # Set up S3 mocks
      expect(Settings).to receive(:decision_review).exactly(6).times.and_return(double)
      expect(Settings.decision_review).to receive(:s3).exactly(5).times.and_return(double)
      expect(Settings.decision_review.s3).to receive(:bucket)
        .and_return('bucket')
      expect(Settings.decision_review.s3).to receive(:region)
        .and_return('region')
      expect(Settings.decision_review.s3).to receive(:access_key_id).and_return('key')
      expect(Settings.decision_review.s3).to receive(:secret_access_key)
        .and_return('secret')

      s3 = double
      expect(Aws::S3::Resource).to receive(:new).once.with(
        region: 'region',
        access_key_id: 'key',
        secret_access_key: 'secret'
      ).and_return(s3)
      bucket = double
      expect(s3).to receive(:bucket).once.with('bucket').and_return(bucket)
      obj = double
      expect(bucket).to receive(:object).once.with(csv_filename).and_return(obj)
      expect(obj).to receive(:upload_file).once.with(path_to_csv, content_type: 'text/csv')
      url = 'http://test'
      expect(obj).to receive(:presigned_url).once.with(:get, expires_in: 1.week.to_i).and_return(url)

      # Set up MPI mocks
      allow(MPI::Service).to receive(:new).exactly(6).times.and_return(double)
      expect(MPI::Service.new).to receive(:find_profile_by_identifier)
                              .once
        .with(identifier: icn1, identifier_type: 'ICN')
        .and_return(double(MPI::Responses::FindProfileResponse, profile: mpi_profile1))

      expect(MPI::Service.new).to receive(:find_profile_by_identifier)
                              .once
        .with(identifier: icn2, identifier_type: 'ICN')
        .and_return(double(MPI::Responses::FindProfileResponse, profile: mpi_profile2))

      expect(MPI::Service.new).to receive(:find_profile_by_identifier)
                              .once
        .with(identifier: icn3, identifier_type: 'ICN')
        .and_return(double(MPI::Responses::FindProfileResponse, profile: mpi_profile3))

      # Set up Vet360 mocks
      expect(VAProfile::ContactInformation::Service).to receive(:get_person)
        .once
        .with(vet360_id1)
        .and_return(double(VAProfile::ContactInformation::PersonResponse,
                           person: vet360_profile1))

      expect(VAProfile::ContactInformation::Service).to receive(:get_person)
        .once
        .with(vet360_id2)
        .and_return(double(VAProfile::ContactInformation::PersonResponse,
                           person: vet360_profile2))

      expect(VAProfile::ContactInformation::Service).to receive(:get_person)
        .once
        .with(vet360_id3)
        .and_return(double(VAProfile::ContactInformation::PersonResponse,
                           person: vet360_profile3))

      # Set up BGS mocks
      expect(BGS::Services).to receive(:new).exactly(4).times.and_return(double(BGS::Services, config: {}))

      # NOTE: Using `receive_message_chain` is not recommended,
      # but we aren't testing BGS as a part of these specs, just need to stub to allow the script to run
      # Also can't chain a count (i.e. `exactly`) to the `expect`
      # because receive_message_chain isn't intended to use the whole interface
      # rubocop:disable RSpec/MessageChain
      allow(BGS::Services.new(external_uid: anything,
                              external_key: anything)).to receive_message_chain(:people, :find_person_by_ptcpnt_id)
        .and_return(bgs_person1, bgs_person2, bgs_person3)
      # rubocop:enable RSpec/MessageChain

      run_rake_task

      # Assertions
      result = CSV.read(path_to_csv)
      first_row, second_row, third_row = result
      expect(first_row).to eq(expected_result1)
      expect(second_row).to eq(expected_result2)
      expect(third_row).to eq(expected_result3)
    end

    it 'logs an error message with the veteran_icn' do
      # Set up S3 mocks
      expect(Settings).to receive(:decision_review).exactly(6).times.and_return(double)
      expect(Settings.decision_review).to receive(:s3).exactly(5).times.and_return(double)
      expect(Settings.decision_review.s3).to receive(:bucket)
        .and_return('bucket')
      expect(Settings.decision_review.s3).to receive(:region)
        .and_return('region')
      expect(Settings.decision_review.s3).to receive(:access_key_id).and_return('key')
      expect(Settings.decision_review.s3).to receive(:secret_access_key)
        .and_return('secret')

      s3 = double
      expect(Aws::S3::Resource).to receive(:new).once.with(
        region: 'region',
        access_key_id: 'key',
        secret_access_key: 'secret'
      ).and_return(s3)
      bucket = double
      expect(s3).to receive(:bucket).once.with('bucket').and_return(bucket)
      obj = double
      expect(bucket).to receive(:object).once.with(csv_filename).and_return(obj)
      expect(obj).to receive(:upload_file).once.with(path_to_csv, content_type: 'text/csv')
      url = 'http://test'
      expect(obj).to receive(:presigned_url).once.with(:get, expires_in: 1.week.to_i).and_return(url)

      # Set up MPI mocks
      allow(MPI::Service).to receive(:new).exactly(6).times.and_return(double)
      expect(MPI::Service.new).to receive(:find_profile_by_identifier)
                              .once
        .with(identifier: icn1, identifier_type: 'ICN')
        .and_return(double(MPI::Responses::FindProfileResponse, profile: mpi_profile1))

      expect(MPI::Service.new).to receive(:find_profile_by_identifier)
                              .once
        .with(identifier: icn2, identifier_type: 'ICN')
        .and_return(double(MPI::Responses::FindProfileResponse, profile: nil))

      expect(MPI::Service.new).to receive(:find_profile_by_identifier)
                              .once
        .with(identifier: icn3, identifier_type: 'ICN')
        .and_return(double(MPI::Responses::FindProfileResponse, profile: mpi_profile3))

      # Set up Vet360 mocks
      expect(VAProfile::ContactInformation::Service).to receive(:get_person)
        .once
        .with(vet360_id1)
        .and_return(double(VAProfile::ContactInformation::PersonResponse,
                           person: vet360_profile1))

      expect(VAProfile::ContactInformation::Service).to receive(:get_person)
        .once
        .with(vet360_id3)
        .and_return(double(VAProfile::ContactInformation::PersonResponse,
                           person: vet360_profile3))

      # Set up BGS mocks
      expect(BGS::Services).to receive(:new).exactly(3).times.and_return(double(BGS::Services, config: {}))

      # NOTE: Using `receive_message_chain` is not recommended,
      # but we aren't testing BGS as a part of these specs, just need to stub to allow the script to run
      # Also can't chain a count (i.e. `exactly`) to the `expect`
      # because receive_message_chain isn't intended to use the whole interface
      # rubocop:disable RSpec/MessageChain
      allow(BGS::Services.new(external_uid: anything,
                              external_key: anything)).to receive_message_chain(:people, :find_person_by_ptcpnt_id)
        .and_return(bgs_person1, bgs_person3)
      # rubocop:enable RSpec/MessageChain

      expected_error_message = {
        message: 'Error while attempting to retrieve veteran contact information: No mpi profile!',
        veteran_icn: icn2,
        backtrace: kind_of(Array)
      }

      expect(Rails.logger).to receive(:error).with(expected_error_message)
      run_rake_task

      # Assertions
      result = CSV.read(path_to_csv)
      first_row, second_row = result
      expect(first_row).to eq(expected_result1)
      # 2nd row will be test veteran #3 since veteran #2 encountered an error
      expect(second_row).to eq(expected_result3)
    end
  end
end
