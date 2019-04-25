# frozen_string_literal: true

def stub_poa_verification
  verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
  allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
  allow(verifier_stub).to receive(:verify)
end
