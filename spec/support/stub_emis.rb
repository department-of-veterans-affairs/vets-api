def stub_emis
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:veteran?).and_return(true)
  allow_any_instance_of(EMISRedis::MilitaryInformation).to receive(:last_branch_of_service)
end
