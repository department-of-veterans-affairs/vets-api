require "rails_helper"
require "rake"

describe "vet360 rake tasks" do

  before :all do
    Rake.application.rake_require "../rakelib/vet360"
    Rake::Task.define_task(:environment)
  end

  describe "rake vet360:get_person" do
    let :run_rake_task do
      Rake::Task["vet360:get_person"].reenable
      Rake.application.invoke_task "vet360:get_person[1]"
    end
    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/person', VCR::MATCH_EVERYTHING) do
        expect { run_rake_task }.not_to raise_error
      end
    end
  end

  describe "rake vet360:get_email_transaction_status" do
    let :run_rake_task do
      Rake::Task["vet360:get_email_transaction_status"].reenable
      Rake.application.invoke_task "vet360:get_email_transaction_status[1,786efe0e-fd20-4da2-9019-0c00540dba4d]"
    end
    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
        expect { run_rake_task }.not_to raise_error
      end
    end
  end

  describe "rake vet360:get_address_transaction_status" do
    let :run_rake_task do
      Rake::Task["vet360:get_address_transaction_status"].reenable
      Rake.application.invoke_task "vet360:get_address_transaction_status[1,0faf342f-5966-4d3f-8b10-5e9f911d07d2]"
    end
    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/address_transaction_status', VCR::MATCH_EVERYTHING) do
        expect { run_rake_task }.not_to raise_error
      end
    end
  end

  describe "rake vet360:get_telephone_transaction_status" do
    let :run_rake_task do
      Rake::Task["vet360:get_telephone_transaction_status"].reenable
      Rake.application.invoke_task "vet360:get_telephone_transaction_status[1,a50193df-f4d5-4b6a-b53d-36fed2db1a15]"
    end
    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/telephone_transaction_status', VCR::MATCH_EVERYTHING) do
        expect { run_rake_task }.not_to raise_error
      end
    end
  end

  describe "rake vet360:put_email" do

    let :run_rake_task do
      data = '{"email_address_text":"person42@example.com","email_id":42,"originating_source_system":"VETSGOV","source_date":"2018-04-09T11:52:03.000-06:00","vet360_id":"1"}'
      ENV['VET360_RAKE_DATA'] = data
      Rake::Task["vet360:put_email"].reenable
      Rake.application.invoke_task "vet360:put_email"
    end
    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/put_email_success', VCR::MATCH_EVERYTHING) do
        expect { run_rake_task }.not_to raise_error
      end
    end
  end








end



# bundle exec spring stop && SIMPLECOV=false bundle exec spring rspec --color  --format d spec/
