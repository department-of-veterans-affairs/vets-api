# Dependency Claim Submission Flow Overview

This is a legacy document of the flow that was used during the V1 and V2 versions of the Dependents Application.
It is here for legacy reference only.

## I. Controller (app/controllers/v0/dependents\_applications\_controller.rb)

1. Create method is called  
2. Attempt to save claim  
   - If save fails:  
     - Increase StatsD  
     - Raise Common::Exceptions::ValidationErrors  
   - If save succeeds:  
     - Call claim.process\_attachments\!  
       - Parse form for child\_documents and spouse\_documents  
       - Update PersistentAttachment saved\_claim\_id  
     - Call dependent\_service.submit\_686c\_form(claim)  
     - Log confirmation number and FORM type  
     - Return JSON response using SavedClaimSerializer.new(claim)

## II. Dependents Service (app/services/bgs/dependent\_service.rb)

1. Log service running (uuid, saved\_claim\_id, icn)  
2. Find and update InProgressForm status  
3. Encrypt form hash  
4. Generate veteran information  
   - Pull bgs\_person data  
   - Set @file\_number  
   - Generate hash with veteran details  
5. Submit PDF job  
   - ~Call VBMS::SubmitDependentsPdfJob.perform\_sync~
   - If fails, submit to central service (Lighthouse)  
6. Determine form type (686 or 674\)  
7. Submit to standard service  
   - If 686: Run BGS::SubmitForm686cJob  
   - If 674: Run BGS::SubmitForm674Job

## III. Submit to CentralMail/Lighthouse (app/sidekiq/central\_mail/submit\_central\_form686c\_job.rb)

1. Decrypt params and assign vet\_info and user\_struct  
2. Log job running  
3. Find claim and add veteran info  
4. Process PDFs and attachments  
5. Upload to Lighthouse  
   - Log attempt  
   - Create BenefitsIntakeService  
   - Upload form  
   - Create FormSubmission and FormSubmissionAttempt  
6. Check submission success  
   - If successful: Log success, update submission, send confirmation email  
   - If unsuccessful: Log failure, raise CentralMailResponseError  
7. Error handling:  
   - Log warning if job fails  
   - Retry up to 14 times  
   - Log final failure and increase StatsD if all retries exhausted

## IV. PDF Submission (app/sidekiq/vbms/submit\_dependents\_pdf\_job.rb)

1. Parse encrypted\_vet\_info and log job running  
2. Find claim and add veteran info  
3. Validate claim (SSN and Dependent Application presence)  
4. Upload attachments  
   - Process jpg, jpeg, png, pdf files  
   - Upload to VBMS  
   - Delete existing file and update completion time  
5. Generate and upload PDFs (686C-674 and/or 21-674)  
6. Log successful upload  
7. Error handling:  
   - Log and retry on failure (up to 14 times)  
   - Log final failure if retries exhausted

## V. Submit 686c Job (app/sidekiq/bgs/submit\_form686c\_job.rb)

1. Log job running  
2. Set instance params  
3. Submit forms  
   - Add veteran info  
   - Validate and normalize data  
   - Submit to BGS::Form686c  
4. If also a 674 claim, enqueue BGS::SubmitForm674Job  
5. Send confirmation email  
6. Log success and destroy InProgressForm (unless also 674 claim)  
7. Error handling:  
   - Check against FILTERED\_ERRORS  
   - Send backup submission for filtered errors  
   - If retries exhausted, send backup submission and destroy InProgressForm

## VI. Submit 674 Job (app/sidekiq/bgs/submit\_form674\_job.rb)

1. Log job running  
2. Set instance params  
3. Submit form  
   - Add veteran info  
   - Validate and normalize data  
   - Submit to BGS::Form674  
4. Send confirmation email  
5. Log success and destroy InProgressForm  
6. Error handling:  
   - Similar to 686c job

## VII. BGS::Form686c (lib/bgs/form686c.rb)

1. Set state type  
2. Create proc\_id  
3. Create veteran record  
4. Process relationships (dependents, marriages, children)  
5. Create vnp\_benefit\_claim  
6. Set claim type  
7. Create BenefitClaim  
8. Update vnp\_benefit\_claim  
9. Prepare manual claim if necessary  
10. Update proc state  
11. Error handling: Log warning if submission fails

## VIII. BGS::Form674 (lib/bgs/form674.rb)

1. Create veteran record  
2. Process relationship (create DependentHigherEdAttendance)  
3. Create StudentSchool  
4. Create vnp\_benefit\_claim  
5. Set claim type (always 'MANUAL\_VAGOV')  
6. Create BenefitClaim  
7. Update vnp\_benefit\_claim  
8. Create note for manual review  
9. Update proc state  
10. Error handling: Log warning if submission fails

