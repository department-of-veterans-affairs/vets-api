# frozen_string_literal: true

RSpec.shared_context 'shared reporting defaults' do
  let(:upload_claims) do
    upload_claims = []
    upload_claims.push(create(:auto_established_claim,
                              :errored,
                              cid: '0oa9uf05lgXYk6ZXn297',
                              evss_response: nil))
    upload_claims.push(create(:auto_established_claim,
                              :errored,
                              cid: '0oa9uf05lgXYk6ZXn297',
                              evss_response: 'random string'))
    evss_response_array = [{ 'key' => 'key-here', 'severity' => 'FATAL', 'text' => 'message-here' }]
    upload_claims.push(create(:auto_established_claim,
                              :errored,
                              cid: '0oa9uf05lgXYk6ZXn297',
                              evss_response: evss_response_array))
    upload_claims.push(create(:auto_established_claim,
                              :errored,
                              cid: '0oa9uf05lgXYk6ZXn297',
                              evss_response: evss_response_array.to_json))
    upload_claims.push(create(:auto_established_claim,
                              :errored,
                              cid: '0oa9uf05lgXYk6ZXn297',
                              evss_response: evss_response_array.to_json))
    upload_claims.push(create(:auto_established_claim,
                              :errored,
                              cid: '0oa9uf05lgXYk6ZXn297',
                              evss_response: evss_response_array.to_json))
  end
  let(:pending_claims) { create(:auto_established_claim, cid: '0oa9uf05lgXYk6ZXn297') }
  let(:poa_submissions) do
    poa_submissions = []
    poa_submissions.push(create(:power_of_attorney,
                                cid: '0oa9uf05lgXYk6ZXn297'))
    poa_submissions.push(create(:power_of_attorney,
                                cid: '0oa9uf05lgXYk6ZXn297'))
    poa_submissions.push(create(:power_of_attorney,
                                cid: '0oa9uf05lgXYk6ZXn297'))
  end
  let(:errored_poa_submissions) do
    errored_poa_submissions = []
    errored_poa_submissions.push(create(:power_of_attorney, :errored, cid: '0oa9uf05lgXYk6ZXn297'))
    errored_poa_submissions.push(create(
                                   :power_of_attorney,
                                   :errored,
                                   vbms_error_message: 'File could not be retrieved from AWS',
                                   cid: '0oa9uf05lgXYk6ZXn297'
                                 ))
    errored_poa_submissions.push(create(:power_of_attorney, cid: '0oa9uf05lgXYk6ZXn297'))
  end
  let(:evidence_waiver_submissions) do
    evidence_waiver_submissions = []
    evidence_waiver_submissions.push(create(:evidence_waiver_submission,
                                            cid: '0oa9uf05lgXYk6ZXn297'))
    evidence_waiver_submissions.push(create(:evidence_waiver_submission,
                                            cid: '0oa9uf05lgXYk6ZXn297'))
    evidence_waiver_submissions.push(create(:evidence_waiver_submission,
                                            cid: '0oa9uf05lgXYk6ZXn297'))
  end
  let(:errored_evidence_waiver_submissions) do
    errored_evidence_waiver_submissions = []
    errored_evidence_waiver_submissions.push(create(:evidence_waiver_submission, :errored,
                                                    cid: '0oa9uf05lgXYk6ZXn297'))
    errored_evidence_waiver_submissions.push(create(
                                               :evidence_waiver_submission,
                                               :errored,
                                               vbms_error_message: 'File could not be retrieved from AWS',
                                               cid: '0oa9uf05lgXYk6ZXn297'
                                             ))
    errored_evidence_waiver_submissions.push(create(:evidence_waiver_submission,
                                                    cid: '0oa9uf05lgXYk6ZXn297'))
  end
end
