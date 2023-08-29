# frozen_string_literal: true

def stub_va_profile
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:veteran?).and_return(true)
  allow_any_instance_of(EMISRedis::VeteranStatus).to receive(:military_person?).and_return(true)
  allow_any_instance_of(FormProfile).to receive(:initialize_military_information).and_return({})
end
