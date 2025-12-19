# BGS proc_id Rules and Limitations

Rules, constraints, and limitations for working with `proc_id` in BGS submissions for 686c and 674 forms.

## Database Constraints

### VNP_PROC_FORM Unique Constraint
**Composite Key**: `proc_id` + `form_type_cd`

- Same `proc_id` with different `form_type_cd` values -> sucess
- Same `proc_id` with same `form_type_cd` -> Error: `(CORPPROD.PK_VNP_PROC_FORM) violated`

### Tables Involved in 686c/674 Submissions

**Tables with proc_id constraints**:
- `VNP_PROC` - `proc_id` is unique key
- `VNP_PROC_FORM` - `proc_id` + `form_type_cd` composite key

**Tables without proc_id constraints** (use own generated IDs):
- `VNP_PERSON`, `VNP_PTCPNT`, `VNP_PTCPNT_RLNSHP`, `VNP_PTCPNT_ADDRS`, `VNP_PTCPNT_PHONE`
- `VNP_CHILD_SCHOOL`, `VNP_CHILD_STUDNT`, `VNP_BNFT_CLAIM`

**Implication**: Downstream operations (dependent creation, relationships, benefit claims) are safe for `proc_id` reuse.

## Form Association Rules

### Combined Submission (686c + 674)
- One `proc_id` for entire submission
- One `claim_id` for entire submission
- Two `proc_form` records: one for '21-686C', one for '21-674'

### Separate Submissions
- Different `proc_id` and `claim_id` per form
- Forms appear as standalone
- Association via veteran identifier (SSN/file number)

### Multiple 674 Dependents
- All can share same `proc_id` and same `proc_form` record
- Each dependent gets own job execution
- Each creates own records in downstream tables

### Retry Requirements
- Create `proc_form` records before job execution
- Cannot retry `proc_form` creation with same `proc_id` + `form_type_cd`
- Downstream operations can retry safely

## Available BGS Service Methods

### Create Operations
```ruby
# Create a new proc record
create_proc(proc_state:)
# Returns: { vnp_proc_id: '...' }

# Create a new proc_form record
create_proc_form(vnp_proc_id, form_type_cd)
# Returns: success/failure
# Will raise error if proc_id + form_type_cd already exists
```

### Finder Operations
```ruby
# Find proc by primary key
vnp_proc_find_by_primary_key(vnp_proc_id)
# Returns: proc record or nil

# Find proc_form by composite key
vnp_proc_form_find_by_primary_key(vnp_proc_id, form_type_cd)
# Returns: proc_form record or nil
```

## Veteran Identification

- **Primary**: File number or SSN
- **Secondary**: Participant ID

Used to look up submissions and associate separate 686c/674 forms.

## References

- **GitHub Issue**: [va.gov-team#123181](https://github.com/department-of-veterans-affairs/va.gov-team/issues/123181)
