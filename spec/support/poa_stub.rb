# frozen_string_literal: true

require 'evss/power_of_attorney_verifier'

def stub_poa_verification
  verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
  allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
  allow(verifier_stub).to receive(:verify)
  allow(verifier_stub).to receive(:current_poa).and_return('A01')
end
