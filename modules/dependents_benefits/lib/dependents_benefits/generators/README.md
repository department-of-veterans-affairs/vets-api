# Dependents Benefits Generators

This directory contains generator classes for creating dependent claims from combined form submissions.

## Overview

The generators in this folder handle the process of splitting a combined 686c-674 form submission into individual `SavedClaim` records for each claim type (686c and 674). This allows the system to process each claim type separately while maintaining a link between related claims.

## Architecture

### Base Generator

- **`DependentClaimGenerator`** - Abstract base class that defines the common interface and workflow for all dependent claim generators

### Workflow

1. **Initialize** with form data and parent claim ID
2. **Extract** relevant form data for the specific claim type
3. **Create** a new `SavedClaim` with the extracted data
4. **Link** the new claim to the parent claim (TODO: implement grouping)

## Usage

Generators should be subclassed from `DependentClaimGenerator` and implement:

- `extract_form_data` - Extract relevant data for the specific claim type
- `form_id` - Return the appropriate form ID (e.g., '686C-674', '21-674')

```ruby
class Form686cGenerator < DependentClaimGenerator
  private

  def extract_form_data
    # Extract 686c-specific data from @form_data
  end

  def form_id
    '686C-674'
  end
end

# Usage
generator = Form686cGenerator.new(combined_form_data, parent_claim_id)
claim = generator.generate
```

## Implementation Notes

- Each generator creates a separate `DependentsBenefits::SavedClaim` record
- Form data is stored as JSON in the `form` field
- Claims are validated before saving
- Claim grouping functionality is planned but not yet implemented

## Future Work

- Implement claim grouping to link related claims
- Differentiate validation for extracted form data by using multiple vets-json-schema schemas
