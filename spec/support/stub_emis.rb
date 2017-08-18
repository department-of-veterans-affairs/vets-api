def stub_emis
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:veteran?).and_return(true)
  allow(EMISRedis::MilitaryInformation).to receive(:for_user).and_return(double.as_null_object)
end
