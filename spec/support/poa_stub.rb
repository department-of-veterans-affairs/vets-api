# frozen_string_literal: true

def stub_poa_verification
  veteran_user_stub = instance_double(Veteran::User)
  allow(Veteran::User).to receive(:new).and_return(veteran_user_stub)

  poa_stub = instance_double(PowerOfAttorney, code: 'A01')
  allow(veteran_user_stub).to receive(:power_of_attorney).and_return(poa_stub)
end
