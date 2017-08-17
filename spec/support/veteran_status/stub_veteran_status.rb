# frozen_string_literal: true
def stub_veteran_status(is_veteran = true)
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:veteran?).and_return(is_veteran)
end
