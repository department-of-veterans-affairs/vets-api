# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'vet360 rake tasks' do
  before :all do
    Rake.application.rake_require '../rakelib/vet360'
    Rake::Task.define_task(:environment)
  end

  before do
    # Prevents cross-pollination between tests
    ENV['VET360_RAKE_DATA'] = nil
    allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(false)
  end

  service = VAProfile::ContactInformation::Service
  cassette_path = 'va_profile/contact_information'

  describe 'rake vet360:get_person' do
    let :run_rake_task do
      Rake::Task['vet360:get_person'].reenable
      Rake.application.invoke_task 'vet360:get_person[1]'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:get_person)
      VCR.use_cassette("#{cassette_path}/person", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:get_email_transaction_status' do
    let :run_rake_task do
      Rake::Task['vet360:get_email_transaction_status'].reenable
      Rake.application.invoke_task 'vet360:get_email_transaction_status[1,786efe0e-fd20-4da2-9019-0c00540dba4d]'
    end
    let :fail_rake_task do
      Rake::Task['vet360:get_email_transaction_status'].reenable
      Rake.application.invoke_task 'vet360:get_email_transaction_status[]'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:get_email_transaction_status)
      VCR.use_cassette("#{cassette_path}/email_transaction_status", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end

    it 'aborts' do
      expect_any_instance_of(service).not_to receive(:get_email_transaction_status)
    end
  end

  describe 'rake vet360:get_address_transaction_status' do
    let :run_rake_task do
      Rake::Task['vet360:get_address_transaction_status'].reenable
      Rake.application.invoke_task 'vet360:get_address_transaction_status[1,0faf342f-5966-4d3f-8b10-5e9f911d07d2]'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:get_address_transaction_status)
      VCR.use_cassette("#{cassette_path}/address_transaction_status", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:get_telephone_transaction_status' do
    let :run_rake_task do
      Rake::Task['vet360:get_telephone_transaction_status'].reenable
      Rake.application.invoke_task 'vet360:get_telephone_transaction_status[1,a50193df-f4d5-4b6a-b53d-36fed2db1a15]'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:get_telephone_transaction_status)
      VCR.use_cassette("#{cassette_path}/telephone_transaction_status", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:get_permission_transaction_status' do
    let :run_rake_task do
      Rake::Task['vet360:get_permission_transaction_status'].reenable
      Rake.application.invoke_task 'vet360:get_permission_transaction_status[1,b1b06a34-c6a8-412e-82e7-df09d84862f3]'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:get_permission_transaction_status)
      VCR.use_cassette("#{cassette_path}/permission_transaction_status", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:put_email' do
    let :run_rake_task do
      data = '{"email_address_text":"person42@example.com","email_id":42,' \
             '"originating_source_system":"VETSGOV","source_date":"2018-04-09T11:52:03.000-06:00","vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:put_email'].reenable
      Rake.application.invoke_task 'vet360:put_email'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:put_email)
      VCR.use_cassette("#{cassette_path}/put_email_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:put_telephone' do
    let :run_rake_task do
      data = '{"area_code":"303","country_code":"1","international_indicator":false,' \
             '"originating_source_system":"VETSGOV","phone_number":"5551235","phone_number_ext":null,' \
             '"phone_type":"MOBILE","source_date":"2018-04-09T11:52:03.000-06:00","telephone_id":1299,' \
             '"tty_ind":true,"vet360_id":"1","voice_mail_acceptable_ind":true}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:put_telephone'].reenable
      Rake.application.invoke_task 'vet360:put_telephone'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:put_telephone)
      VCR.use_cassette("#{cassette_path}/put_telephone_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:put_address' do
    let :run_rake_task do
      data = '{"address_id":437,"address_line1":"1494 Martin Luther King Rd","address_line2":null,' \
             '"address_line3":null,"address_pou":"RESIDENCE/CHOICE","address_type":"domestic","city_name":"Fulton",' \
             '"country_code_ios2":null,"country_code_iso3":null,"country_name":"USA","county":{"county_code":null,' \
             '"county_name":null},"int_postal_code":null,"province_name":null,"state_code":"MS","zip_code5":"38843",' \
             '"zip_code4":null,"originating_source_system":"VETSGOV","source_date":"2018-04-09T11:52:03.000-06:00",' \
             '"vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:put_address'].reenable
      Rake.application.invoke_task 'vet360:put_address'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:put_address)
      VCR.use_cassette("#{cassette_path}/put_address_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:put_permission' do
    let :run_rake_task do
      data = '{"originating_source_system":"VET360-TEST-PARTNER","permission_type":"TextPermission",' \
             '"permission_value":true,"source_date":"2019-09-23T20:09:50.000-06:00","permission_id":42,' \
             '"vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:put_permission'].reenable
      Rake.application.invoke_task 'vet360:put_permission'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:put_permission)
      VCR.use_cassette("#{cassette_path}/put_permission_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:post_email' do
    let :run_rake_task do
      data = '{"email_address_text":"person42@example.com","email_id":null,"originating_source_system":"VETSGOV",' \
             '"source_date":"2018-04-09T11:52:03.000-06:00","vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:post_email'].reenable
      Rake.application.invoke_task 'vet360:post_email'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:post_email)
      VCR.use_cassette("#{cassette_path}/post_email_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:post_telephone' do
    let :run_rake_task do
      data = '{"area_code":"303","country_code":"1","international_indicator":false,' \
             '"originating_source_system":"VETSGOV","phone_number":"5551234","phone_number_ext":null,' \
             '"phone_type":"MOBILE","source_date":"2018-04-09T11:52:03.000-06:00","telephone_id":null,' \
             '"tty_ind":true,"vet360_id":"1","voice_mail_acceptable_ind":true}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:post_telephone'].reenable
      Rake.application.invoke_task 'vet360:post_telephone'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:post_telephone)
      VCR.use_cassette("#{cassette_path}/post_telephone_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:post_address' do
    let :run_rake_task do
      data = '{"address_id":null,"address_line1":"1493 Martin Luther King Rd","address_line2":null,' \
             '"address_line3":null,"address_pou":"RESIDENCE/CHOICE","address_type":"domestic","city_name":"Fulton",' \
             '"country_code_iso2":null,"country_code_iso3":null,"country_name":"USA","county":{"county_code":null,' \
             '"county_name":null},"int_postal_code":null,"province_name":null,"state_code":"MS","zip_code5":"38843",' \
             '"zip_code4":null,"originating_source_system":"VETSGOV","source_date":"2018-04-09T11:52:03.000-06:00",' \
             '"vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:post_address'].reenable
      Rake.application.invoke_task 'vet360:post_address'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:post_address)
      VCR.use_cassette("#{cassette_path}/post_address_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:post_permission' do
    let :run_rake_task do
      data = '{"originating_source_system":"VET360-TEST-PARTNER","permission_type":"TextPermission",' \
             '"permission_value":true,"source_date":"2019-09-23T20:09:50.000-06:00","permission_id":null,' \
             '"vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:post_permission'].reenable
      Rake.application.invoke_task 'vet360:post_permission'
    end

    it 'runs without errors' do
      expect_any_instance_of(service).to receive(:post_permission)
      VCR.use_cassette("#{cassette_path}/post_permission_success", VCR::MATCH_EVERYTHING) do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'rake vet360:prep_error_codes' do
    let :run_rake_task do
      Rake::Task['vet360:prep_error_codes'].reenable
      Rake.application.invoke_task 'vet360:prep_error_codes'
    end

    it 'runs without errors' do
      expect_any_instance_of(VAProfile::Exceptions::Builder).to receive(:construct_exceptions_from_csv)

      expect { silently { run_rake_task } }.not_to raise_error
    end
  end

  describe 'rake vet360:init_vet360_id' do
    let :run_rake_task do
      data = '123456,1312312'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task['vet360:init_vet360_id'].reenable
      Rake.application.invoke_task 'vet360:init_vet360_id'
    end

    it 'runs without errors' do
      VCR.use_cassette('va_profile/person/init_vet360_id_success') do
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end
end

def silently
  # Store the original stderr and stdout in order to restore them later
  @original_stderr = $stderr
  @original_stdout = $stdout

  # Redirect stderr and stdout
  $stderr = $stdout = StringIO.new

  yield

  $stderr = @original_stderr
  $stdout = @original_stdout
  @original_stderr = nil
  @original_stdout = nil
end
