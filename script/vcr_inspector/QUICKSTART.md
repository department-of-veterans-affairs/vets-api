# 🎬 VCR Inspector - Quick Start Guide

## What You Just Built

A **retro VCR-themed web interface** for browsing and inspecting the ~1,940 VCR cassettes in vets-api! 📼✨

The tool features:
- 🎨 **Nostalgic VCR player aesthetic** with animated cassette reels
- 🔍 **Powerful search** across all cassettes
- 📦 **Detailed HTTP inspection** with pretty-printed JSON
- 🧪 **Test usage analysis** showing which specs use each cassette
- ⚡ **No dependencies** - uses only Ruby stdlib (WEBrick, ERB, YAML, JSON)

## Usage

### Start the Server
```bash
bin/vcr-inspector

# Or specify a custom port
PORT=3000 bin/vcr-inspector
```

The tool will open at **http://localhost:4567**

### Browse Cassettes
- **Home Page**: Shows all cassettes organized by service (BGS, MVI, Lighthouse, etc.)
- Each service section shows up to 12 cassettes with animated VHS tape visuals
- Click "+ X more" to see all cassettes for that service

### Search
- Press `/` anywhere to focus the search box (GitHub-style)
- Search by cassette name, path, or service
- Use filters for advanced queries
- Press `Esc` to clear the search

### View Cassette Details
Click any cassette to see:
- **Animated cassette insertion** - watch the cassette slide into the VCR! 
- **Physical cassette visualization** with rotating reels
- **Metadata**: Recording date, age indicator (🆕/📼/⚠️/🕰️), file size, interaction count
- **Test usage**: Which spec files reference this cassette
- **HTTP interactions**: Full request/response details with:
  - Pretty-printed JSON with syntax highlighting
  - Collapsible headers
  - Copy buttons for URLs and payloads
  - Status code color coding (green/yellow/red)
  - HTTP method badges

### Keyboard Shortcuts
- `/` - Focus search
- `Esc` - Clear search and blur

## Features

### Visual Elements
- **VCR Player UI**: Complete with digital counter, control buttons, and status LEDs
- **Animated Cassette Reels**: Spin when you hover over cassettes
- **Physical Cassette View**: See the cassette being "inserted" into the player with moving tape ribbon
- **Color-Coded Status**: Green for 2xx, yellow for 3xx/4xx, red for 5xx responses

### JSON Handling
- Auto-detects JSON in request/response bodies
- Pretty-prints with proper indentation
- Syntax highlighting via CSS
- One-click copy buttons

### Test Analysis
- Shows every test file that uses each cassette
- Displays file path and line number
- Shows the actual `VCR.use_cassette` line

### Cassette Age Indicators
- 🆕 < 30 days old
- 📼 30-180 days
- ⚠️ 180-365 days  
- 🕰️ > 1 year old

## Architecture

```
lib/vcr_inspector/
├── app.rb              # WEBrick web server & routing
├── cassette_finder.rb  # Search & index cassettes
├── cassette_parser.rb  # YAML parser with JSON detection
├── test_analyzer.rb    # Find test references via grep
├── views/              # ERB templates
│   ├── layout.erb      # Main VCR player layout
│   ├── index.erb       # Cassette library homepage
│   ├── cassette.erb    # Detailed cassette viewer
│   ├── services.erb    # Browse by service
│   ├── search_results.erb
│   └── not_found.erb
└── public/             # Static assets
    ├── style.css       # Retro VCR theme (~800 lines!)
    └── script.js       # Interactive features

bin/vcr-inspector       # Launcher script
```

## Tips & Tricks

1. **Find error responses**: Click a service, then look for red status badges
2. **Check cassette freshness**: Look for 🕰️ indicators - those might have outdated data structures
3. **Copy JSON for fixtures**: Use the 📋 copy buttons to grab response payloads for new tests
4. **Understand cassette context**: Check "Tests Using This Cassette" to see how it's used before modifying
5. **Browse by service**: Great way to understand what external APIs the app integrates with

## What Makes It Fun? 🎉

- **VHS Nostalgia**: Complete with cassette tape visuals, rotating reels, and that satisfying "insert" animation
- **No Build Step**: Pure Ruby + ERB + vanilla CSS/JS
- **Fast**: Lazy-loads cassette details, indexes on the fly
- **Self-Contained**: No external dependencies beyond Ruby stdlib
- **Actually Useful**: Solves real pain points with cassette inspection

## Next Steps

Try these enhancements:
- Add cassette comparison (diff two cassettes)
- Export cassettes as `curl` commands  
- Add validation checks (scan for PII/sensitive data)
- Statistics dashboard (most-used cassettes, error rates, etc.)
- Cassette editing capabilities
- Dark/light theme toggle

## Files Created

- `bin/vcr-inspector` - Launcher script
- `lib/vcr_inspector/` - Main application directory
  - `app.rb` - WEBrick web server (252 lines)
  - `cassette_finder.rb` - Search logic (56 lines)
  - `cassette_parser.rb` - YAML parsing (60 lines)
  - `test_analyzer.rb` - Test analysis (48 lines)
  - `views/*.erb` - 6 templates (~400 lines total)
  - `public/style.css` - Retro VCR theme (826 lines!)
  - `public/script.js` - Interactive features (130 lines)
  - `README.md` - Full documentation

**Total**: ~1,800 lines of code delivering a fully functional, beautifully designed VCR cassette inspector! 🚀

## Enjoy!

Now go explore those cassettes with style! Press `/` to search, click cassettes to watch them "insert" into the VCR, and marvel at the spinning tape reels. 📼✨

---

*Built with ❤️ for the vets-api team*
