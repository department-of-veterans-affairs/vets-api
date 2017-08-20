def stub_emis
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:veteran?).and_return(true)
  %w(MilitaryInformation Payment).each do |klass|
    allow("EMISRedis::#{klass}".constantize).to receive(:for_user).and_return(double.as_null_object)
  end
end
