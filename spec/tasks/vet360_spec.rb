require "rails_helper"
require "rake"
# require "rakelib/vet360.rake"

describe "vet360 rake tasks" do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    Rake.application.rake_require "../rakelib/vet360"
    Rake::Task.define_task(:environment)
  end

  describe "rake vet360:get_person" do
    before do
      @task_name = "vet360:get_person"
    end

    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/person', VCR::MATCH_EVERYTHING) do
        expect { @rake[@task_name].invoke('1') }.not_to raise_error
      end
    end
  end

  describe "rake vet360:get_email_transaction_status" do
    before do
      @task_name = "vet360:get_email_transaction_status"
    end

    it "runs without errors" do
      VCR.use_cassette('vet360/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
        expect { @rake[@task_name].invoke('1', '786efe0e-fd20-4da2-9019-0c00540dba4d') }.not_to raise_error
      end
    end
  end

end
