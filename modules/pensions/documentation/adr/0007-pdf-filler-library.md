# 7. PDF Filler Library

Date: 2024-07-10

## Status

Accepted

## Context

In the main app there is a lib called `pdf_filler` and this contains the information about the form key value data itself. It's monolithic engineering design, presents some challenges to moving these dependent files completely out of that folder and creating an extension to this library.

`lib/pdf_fill/filler.rb` would need to be refactored to support incoming module registrations and break out of the monolithic folder structures.
`lib/pdf_fill/forms/va21p527ez.rb` would be the form key value pair that needs to be registered
`lib/pdf_fill/forms/pdfs/21P-527EZ.pdf` would be the form template that needs to be registered

##### Pdf filler specs

`spec/lib/pdf_fill/forms/va21p527ez_spec.rb` and the associated `fixtures` would need to be migrated over to run. This may not be entirely complex.

## Decision

The PDF Filler presents its own set of challenges to bring together as much of these files without changing the core library too much.

## Consequences

Look into bringing over the files with minimal impact to the rest of the team projects. Perhaps as a follow up PR.
