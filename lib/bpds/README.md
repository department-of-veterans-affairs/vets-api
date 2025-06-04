# Overview

The [Benefits Processing Data Service (BPDS)](https://department.va.gov/privacy/wp-content/uploads/sites/5/2024/09/FY24BenefitsProcessingDataServiceBPDSPIA_508.pdf) is a backend service developed to extract, transform, and store structured data from benefits-related form submissions. It acts as a normalized data layer that supports downstream automation and rules engines used in claims adjudication workflows. By centralizing access to preprocessed form data, BPDS reduces the complexity of parsing PDF form content at the point of use and enables faster, rules-driven decision-making.

BPDS typically operates as part of a broader service ecosystem that includes Pension Automation (POI) and other adjudication services. It is deployed within the VA Enterprise Cloud (VAEC) and adheres to VA security and compliance standards. Engineers interact with BPDS primarily through internal APIs or batch processes that query and retrieve structured form data for use in backend processing pipelines, reducing reliance on manual review and improving the scalability of claims systems.

## Additional Documentation and Resources 

- Developers who would like to use the BPDS library can get started by reviewing the [developer setup](documentation/README.md#developer-setup).

- Our team used ADR (Architectual Decision Records) to capture key decisions and discoveries.  A [full list of ADR's](documentation/README.md#list-of-architectual-decisions) has been summarized within the documenation.



## Future Assumptions

05/09/2025

The team that has been working on integrating with BPDS has been focused on using the [21P-527EZ (Pension)](https://www.va.gov/pension/apply-for-veteran-pension-form-21p-527ez/introduction) form for proof of concept.  The next steps outlined here are specificic to that form and the [21P-530EZ](https://www.va.gov/burials-memorials/veterans-burial-allowance/apply-for-allowance-form-21p-530ez/introduction) form.  

Context:

- MAS (Mail Automation System) will continue to establish the claim.
- POI (Program Oversight and Informatics) will need to pickup the data from BDPS and create an automated approval process
- Users that are logged in will have an ICN.

#### Associating a submission with a unique identifier

About 30% of the users on the pension form are not authenticated.  To ensure that we have a unique identifier for the POI system to automate the submissions, our team will need to use a [BEP SOAP service](documentation/VeteranWebService - findVeteranByFileNumber.pdf).  The service has a method called `findVeteranByFileNumber()`. which accepts fileNumber as a parameter.  For the majority of veterans, their file number is their SSN.

Our assumptions is that first we would use the SSN provided in form, as that is a required field.  If there are no results returned, we would then use the file number.  One of the things returned by `findVeteranByFileNumber()` is the participantId (PID). 

Further conversations are needed to determine if POI needs an ICN or a PID

The ICN or PID is then included in the payload that is posted to BPDS.  If no ICN or PID can be found, these submissions will not go to BDPS.

#### Claim ID's and tracking status of submissions

The goal of this project is to have POI automate pension claim approvals.  MAS will continue to create claimID's for submissions that are sent to Lighthouse.  We need a way to link these submissions back to the JSON that has been posted to BDPS, since the POI system relies on the claim ID to process submissions.  

We may eventually generate our own claim IDs for each submission and expose an API endpoint to return a list of unprocessed claim IDs or submissions, but that will be fleshed out when we have more information.
