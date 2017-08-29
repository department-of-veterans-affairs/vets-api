# frozen_string_literal: true
def stub_emis
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:veteran?).and_return(true)
end
