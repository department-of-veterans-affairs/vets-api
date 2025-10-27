# 📼 VCR Inspector

A retro VCR-themed web UI for browsing, searching, and inspecting VCR cassettes in the vets-api codebase.

## Features

### 🎬 Visual Cassette Browser
- Browse ~1,940 VCR cassettes organized by service
- Retro VCR player interface with animated cassette reels
- Physical cassette visualization when viewing details

### 🔍 Powerful Search
- Full-text search across cassette names and paths
- Filter by service, HTTP method, or status code
- Keyboard shortcut: Press `/` to focus search (like GitHub)

### 📦 Detailed Inspection
- View HTTP request/response details
- Pretty-printed JSON with syntax highlighting
- Automatic base64 decoding
- Collapsible sections for headers and bodies
- Copy buttons for URLs and JSON payloads

### 🧪 Test Analysis
- Shows which test files use each cassette
- Direct links to test file locations
- Line numbers for each cassette reference

### 🎨 Retro Aesthetic
- Nostalgic VCR player design
- Animated cassette tape reels
- Digital counter display
- Status LEDs and retro controls

## Quick Start

```bash
# Start the VCR Inspector
bin/vcr-inspector

# Opens automatically at http://localhost:4567
# Or specify a different port:
PORT=3000 bin/vcr-inspector
```

## Usage

### Browse by Service
Click the "SERVICES" button to see all cassettes grouped by external service (BGS, MVI, Lighthouse, etc.)

### Search Cassettes
1. Press `/` anywhere to focus the search box
2. Type your search query
3. Press Enter or click "SEARCH"
4. Use filters to narrow results

### Inspect a Cassette
1. Click any cassette card to view details
2. See the animated cassette being "inserted" into the player
3. Expand HTTP interactions to see full request/response details
4. Use copy buttons to grab URLs or JSON payloads
5. Check which tests use this cassette

### Keyboard Shortcuts
- `/` - Focus search
- `Esc` - Clear search and blur input

## Architecture

```
lib/vcr_inspector/
├── app.rb              # Sinatra web application
├── cassette_finder.rb  # Search and index cassettes
├── cassette_parser.rb  # YAML parser with JSON detection
├── test_analyzer.rb    # Find test references
├── views/              # ERB templates
│   ├── layout.erb      # Main VCR player layout
│   ├── index.erb       # Cassette library
│   ├── cassette.erb    # Detailed cassette view
│   ├── services.erb    # Browse by service
│   ├── search_results.erb
│   └── not_found.erb
└── public/             # Static assets
    ├── style.css       # Retro VCR theme
    └── script.js       # Interactive features
```

## Technical Details

### Dependencies
- **Sinatra** - Lightweight web framework (already in Gemfile)
- **YAML** - Parse cassette files (Ruby stdlib)
- **JSON** - Pretty-print responses (Ruby stdlib)
- **ERB** - Template rendering (Ruby stdlib)

No additional gems needed! Uses only what's already available in vets-api.

### Cassette Locations
- Main cassettes: `spec/support/vcr_cassettes/`
- Module cassettes: `modules/*/spec/support/vcr_cassettes/`
- Test specs: `spec/**/*_spec.rb` and `modules/**/*_spec.rb`

### Features

#### JSON Formatting
- Automatically detects JSON in request/response bodies
- Pretty-prints with proper indentation
- Falls back to raw text for non-JSON content

#### Base64 Decoding
- Detects base64-encoded content
- Attempts automatic decoding
- Shows decoded content when valid

#### Metadata Extraction
- Cassette age indicators (🆕 < 30 days, 🕰️ > 1 year)
- HTTP method badges with color coding
- Status code styling (green for 2xx, red for 5xx)
- Recording timestamps
- File sizes

## Performance

- Fast initial load (~0.5s for 1,940 cassettes)
- Lazy parsing (only parses cassettes when viewed)
- Efficient grep-based test searching
- Lightweight CSS with no frameworks

## Tips

1. **Use service browsing** for exploring specific integrations (BGS, MVI, etc.)
2. **Search by error codes** to find failing interactions: `?status=500`
3. **Copy JSON payloads** to use in new test fixtures
4. **Check cassette age** - old cassettes may have outdated data structures
5. **View test usage** to understand cassette context before modifying

## Visual Elements

### Cassette Card
Each cassette is displayed as a miniature VHS cassette with:
- Animated tape reels
- Service label
- Last modified date with age indicator
- Hover effects with rotation

### Cassette Player View
When viewing a cassette:
- Animated "insertion" of cassette into player
- Rotating reels during playback
- Moving tape ribbon effect
- Physical cassette body with transparent windows

### VCR Controls
- HOME - Return to main library
- SERVICES - Browse by service category
- SEARCH - Focus search input
- Recording indicator - Shows playback status

## Troubleshooting

### Port Already in Use
```bash
# Use a different port
PORT=3001 bin/vcr-inspector
```

### Cassettes Not Found
Make sure you're running from the vets-api root directory:
```bash
cd /path/to/vets-api
bin/vcr-inspector
```

### Slow Search
The first search may take a moment while indexing. Subsequent searches are faster.

## Future Enhancements

Potential additions:
- Compare cassettes (diff view)
- Export cassettes as curl commands
- Cassette validation (check for sensitive data)
- Statistics dashboard
- Dark/light theme toggle
- Cassette editing capabilities

## Credits

Built with ❤️ for the vets-api team. Inspired by the nostalgia of VHS tapes and VCRs. 📼✨
