# frozen_string_literal: true

module BenefitsClaims
  module Constants
    CLAIM_TYPE_LANGUAGE_MAP = {
      'Death' => 'expenses related to death or burial'
    }.freeze

    FRIENDLY_DISPLAY_MAPPING = {
      '21-4142/21-4142a' => 'Authorization to disclose information',
      'Employment info needed' => 'Employment information',
      'EFT - Treasury Mandate Notification' => 'Direct deposit information',
      'PTSD - Need stressor details/med evid of stressful incdnt' => 'Details about cause of PTSD',
      'RV1 - Reserve Records Request' => 'Reserve records',
      'Proof of service (DD214, etc.)' => 'Proof of service',
      'PMR Request' => 'Non-VA medical records',
      'PMR Pending' => 'Non-VA medical records',
      'General Records Request (Medical)' => 'Non-VA medical records',
      'DBQ AUDIO Hearing Loss and Tinnitus' => 'Disability exam for hearing',
      'DBQ PSYCH Mental Disorders' => 'Mental health exam',
      'Employer (21-4192)' => 'Employment information',
      'Unemployability - 21-8940 needed and 4192(s) requested'=> 'Work status information',
      'Request Service Treatment Records from Veteran' => 'Official service treatment records',
      '21-4142 incomplete - need provider address' => 'Address of non-VA medical provider',
      'Submit buddy statement(s)' => 'Witness or corroboration statements',
      'ASB - tell us where, when, how exposed' => 'Asbestos exposure information',
    }.freeze

    ACTIVITY_DESCRIPTION_MAPPING = {
      '21-4142/21-4142a' => 'We need your permission to request your personal information from a non-VA source,' \
                            ' like a private doctor or hospital.',
      'Employment info needed' => 'We need employment information from your most recent employer.',
      'EFT - Treasury Mandate Notification' => 'We need your direct deposit information in order to pay benefits,' \
                                               ' if awarded.',
      'PTSD - Need stressor details/med evid of stressful incdnt' => 'We need information about the cause of' \
                                                                     ' your posttraumatic stress disorder (PTSD).',
      'RV1 - Reserve Records Request' => 'We’ve requested your reserve records on your behalf. No action is needed.',
      'Proof of service (DD214, etc.)' => 'We’ve requested your proof of service on your behalf. No action is needed.',
      'PMR Request' => 'We’ve requested your non-VA medical records on your behalf. No action is needed.',
      'DBQ AUDIO Hearing Loss and Tinnitus' => 'We’ve requested a disability exam for your hearing.' \
                                               ' The examiner’s office will contact you to schedule this appointment.',
      'DBQ PSYCH Mental Disorders' => 'We’ve requested a mental health exam for you. The examiner’s office' \
                                      ' will contact you to schedule this appointment.',
    }.freeze

    SHORT_DESCRIPTION_MAPPING = {
      'RV1 - Reserve Records Request' => 'We’ve requested your service records' \
                                         ' or treatment records from your reserve unit.',
      'Proof of service (DD214, etc.)' => 'We’ve requested all your DD Form 214’s' \
                                          ' or other separation papers for all your periods of military service.',
      'Employer (21-4192)' => 'We sent a letter to your last employer to ask about your job and why you left.',
      'PMR Pending' => 'We’ve requested your non-VA medical records from your medical provider.',
      'General Records Request (Medical)' => 'We’ve requested your non-VA medical records from your medical provider.',
      'Unemployability - 21-8940 needed and 4192(s) requested'=> 'We need more information about how your service-connected disabilities prevent you from working.',
      'Request Service Treatment Records from Veteran' => 'We need certified copies of your service treatment records if you have them.',
      '21-4142 incomplete - need provider address' => 'We need your private physician’s address to request information for your claim.',
      'Submit buddy statement(s)' => 'We need statements from people who know about your condition.',
      'ASB - tell us where, when, how exposed' => 'To process your disability claim for asbestos exposure, we need a bit more information from you.'
    }.freeze

    SUPPORT_ALIASES_MAPPING = {
      '21-4142/21-4142a' => ['21-4142/21-4142a'],
      'Employment info needed' => ['VA Form 21-4192'],
      'EFT - Treasury Mandate Notification' => ['EFT - Treasure Mandate Notification'],
      'PTSD - Need stressor details/med evid of stressful incdnt' => ['VA Form 21-0781',
                                                                      'PTSD - Need stressor details'],
      'RV1 - Reserve Records Request' => ['RV1 - Reserve Records Request'],
      'Proof of service (DD214, etc.)' => ['Proof of Service (DD214, etc.)'],
      'PMR Request' => ['PMR Request', 'General Records Request (Medical)'],
      'General Records Request (Medical)' => ['General Records Request (Medical)', 'PMR Request'],
      'DBQ AUDIO Hearing Loss and Tinnitus' => ['DBQ AUDIO Hearing Loss and Tinnitus'],
      'DBQ PSYCH Mental Disorders' => ['DBQ PSYCH Mental Disorders'],
      'Employer (21-4192)' => ['Employer (21-4192)'],
      'PMR Pending' => ['PMR Pending','General Records Request (Medical)'],
      'Unemployability - 21-8940 needed and 4192(s) requested' => ['Unemployability - 21-8940 needed and 4192(s) requested'],
      'Request Service Treatment Records from Veteran' => ['Request Service Treatment Records from Veteran'],
      '21-4142 incomplete - need provider address' => ['21-4142 incomplete - need provider address'],
      'Submit buddy statement(s)' => ['Submit buddy statement(s)'],
      'ASB - tell us where, when, how exposed' => ['ASB - tell us where, when, how exposed']
    }.freeze

    UPLOADER_MAPPING = {
      '21-4142/21-4142a' => true,
      'Employment info needed' => true,
      'EFT - Treasury Mandate Notification' => false,
      'PTSD - Need stressor details/med evid of stressful incdnt' => true,
      'RV1 - Reserve Records Request' => true,
      'Proof of service (DD214, etc.)' => true,
      'PMR Request' => true,
      'General Records Request (Medical)' => true,
      'DBQ AUDIO Hearing Loss and Tinnitus' => false,
      'DBQ PSYCH Mental Disorders' => false,
      'PMR Pending' => true,
      'Employer (21-4192)' => false,
      'Unemployability - 21-8940 needed and 4192(s) requested' => true,
      'Request Service Treatment Records from Veteran' => true,
      '21-4142 incomplete - need provider address'=> true,
      'Submit buddy statement(s)' => true,
      'ASB - tell us where, when, how exposed' => true
    }.freeze
  end
end
