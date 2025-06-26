# 12. Replace PDFTK with HexaPDF in PdfFill::Filler and Related Modules

Date: 2025-06-24

## Status

Proposed

## Context

PDFTK is currently used in PdfFill::Filler and other modules for PDF manipulation (e.g. form filling, merging, flattening).

PDFTK is no longer actively maintained, and multiple teams have already been transitioning various PDF related functionality to HexaPDF.

A direct cutover from PDFTK to HexaPDF is not recommended due to forms being maintained by different teams. To mitigate any issues, Flipper feature flags can be used to control the rollout of the HexaPDF implementation.

## Decision

Refactor `PdfFill::Filler` to support HexaPDF:
* add a function to use HexaPDF to generate the PDF
* add a parameter or support a new key in the `fill_options` hash that is used by `fill_form` to determine if PDFTK or HexaPDF should be used to generate the PDF

Other files that are using PDFTK specific methods:
* `lib/pdf_fill/extras_generator.rb` - generates additional pages that are appended to the main PDF
* `lib/pdf_fill/extras_generator_v2.rb` - generates additional pages that are appended to the main PDF

Instead of modifying the existing ExtrasGenerators classes, a new ExtrasGenerators using HexaPDF can be added for flexibility.

Update tests and documentation

## Consequences

Gradual transition will ensure that the PDF generation logic can be rolled back if issues are detected. The primary concern is that PDF generation logic is not contained in one place, so PDF outputs will need to be closely examined to ensure there are no issues during the transition process.
