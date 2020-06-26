# CARMA
CARMA (Caregiver Record Management Application)

## Description
CARMA (Caregiver Record Management Application) is a Salesforce application that the VA's Caregivers Program uses to intake, track, and process 10-10CG submissions.

This CARMA service/module is used to submit valid, online, 10-10CG submissions (CaregiversAssistanceClaim) to CARMA. It includes models that map to the Salesforce API interface and an http client.

## Design

### CARMA::Models
Used to hold model objects relating to CARMA's domain. More models can be added as the interface with CARMA grows (i.e. CARMA::Models::Case).

### CARMA::Client
This is an http client used to communicate with CARMA. It contains configuration and auth behavior needed to interface with the Salesforce app. This is an extention of our internal Salesforce service (lib/salesforce) which also extends Restforce (a ruby package for interfacing with the Salesforce API).

## Example

### Simple (available now)
```
claim = CaregiversAssistanceClaim.new

submission = CARMA::Models::Submission.from_claim(claim)
submission.submit!
```

### Advanced (future features)
```
claim = CaregiversAssistanceClaim.new

submission = CARMA::Models::Submission.from_claim(claim)
submission.metadata = {
  veteran: {
    icn: get_icn_for(submission.data[:veteran]),
    is_veteran: verify_veteran(vet_icn)
  }
}

submission.submit!
submission.submit_attachments_async if submission.attachments.any?
```
