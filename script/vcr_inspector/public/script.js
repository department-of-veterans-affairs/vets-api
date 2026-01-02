// VCR Inspector - Client-side JavaScript

// Search keyboard shortcut
document.addEventListener('keydown', (e) => {
  const searchInput = document.getElementById('search-input');
  
  // Focus search on '/' key (like GitHub)
  if (e.key === '/' && !isInputFocused()) {
    e.preventDefault();
    if (searchInput) {
      searchInput.focus();
      searchInput.select();
    }
  }
  
  // Clear search on ESC
  if (e.key === 'Escape' && searchInput) {
    searchInput.value = '';
    searchInput.blur();
  }
});

// Check if any input is currently focused
function isInputFocused() {
  const activeElement = document.activeElement;
  return activeElement && (
    activeElement.tagName === 'INPUT' || 
    activeElement.tagName === 'TEXTAREA' ||
    activeElement.isContentEditable
  );
}

// Toggle shelf visibility
function toggleShelf(button) {
  const shelf = button.closest('.cassette-shelf');
  const content = shelf.querySelector('.shelf-content');
  
  button.classList.toggle('collapsed');
  content.classList.toggle('collapsed');
}

// Copy to clipboard
function copyToClipboard(text) {
  // Decode HTML entities if present
  const textarea = document.createElement('textarea');
  textarea.innerHTML = text;
  const decodedText = textarea.value;
  
  navigator.clipboard.writeText(decodedText).then(() => {
    // Show temporary success indicator
    showNotification('📋 Copied to clipboard!');
  }).catch(err => {
    console.error('Failed to copy:', err);
    showNotification('❌ Failed to copy', true);
  });
}

// Show notification
function showNotification(message, isError = false) {
  // Remove existing notification
  const existing = document.querySelector('.notification');
  if (existing) {
    existing.remove();
  }
  
  const notification = document.createElement('div');
  notification.className = 'notification';
  notification.textContent = message;
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: ${isError ? '#ef4444' : '#10b981'};
    color: white;
    padding: 15px 25px;
    border-radius: 8px;
    box-shadow: 0 5px 20px rgba(0, 0, 0, 0.5);
    z-index: 10000;
    font-family: 'Courier New', monospace;
    font-weight: bold;
    animation: slideIn 0.3s ease-out;
  `;
  
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => notification.remove(), 300);
  }, 2000);
}

// Add CSS animations for notifications
const style = document.createElement('style');
style.textContent = `
  @keyframes slideIn {
    from {
      transform: translateX(400px);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }
  
  @keyframes slideOut {
    from {
      transform: translateX(0);
      opacity: 1;
    }
    to {
      transform: translateX(400px);
      opacity: 0;
    }
  }
`;
document.head.appendChild(style);

// Auto-expand first interaction on cassette page
document.addEventListener('DOMContentLoaded', () => {
  const firstInteraction = document.querySelector('.interaction-card');
  if (firstInteraction) {
    const details = firstInteraction.querySelectorAll('details');
    // Keep body sections open by default (they have 'open' attribute in HTML)
  }
  
  // Add counter animation
  const counter = document.getElementById('counter');
  if (counter && counter.textContent) {
    const targetValue = parseInt(counter.textContent);
    if (!isNaN(targetValue)) {
      animateCounter(counter, 0, targetValue, 1000);
    }
  }
});

// Animate counter on load
function animateCounter(element, start, end, duration) {
  const startTime = performance.now();
  
  function updateCounter(currentTime) {
    const elapsed = currentTime - startTime;
    const progress = Math.min(elapsed / duration, 1);
    
    // Easing function (ease-out)
    const easeOut = 1 - Math.pow(1 - progress, 3);
    const current = Math.floor(start + (end - start) * easeOut);
    
    element.textContent = current;
    
    if (progress < 1) {
      requestAnimationFrame(updateCounter);
    } else {
      element.textContent = end;
    }
  }
  
  requestAnimationFrame(updateCounter);
}

// Add loading state for search
const searchForm = document.querySelector('.search-form');
if (searchForm) {
  searchForm.addEventListener('submit', () => {
    const button = searchForm.querySelector('.search-button');
    if (button) {
      button.textContent = 'SEARCHING...';
      button.style.opacity = '0.6';
    }
  });
}

// Add visual feedback for cassette hover
document.addEventListener('DOMContentLoaded', () => {
  const cassettes = document.querySelectorAll('.cassette-card');
  cassettes.forEach(cassette => {
    cassette.addEventListener('mouseenter', () => {
      const reels = cassette.querySelectorAll('.tape-reel');
      reels.forEach(reel => {
        reel.style.animation = 'rotateTape 0.5s linear infinite';
      });
    });
    
    cassette.addEventListener('mouseleave', () => {
      const reels = cassette.querySelectorAll('.tape-reel');
      reels.forEach(reel => {
        reel.style.animation = 'none';
      });
    });
  });
});

// JSON collapsing functionality
function initJsonCollapsing() {
  document.querySelectorAll('.json-content code').forEach(codeBlock => {
    const text = codeBlock.textContent;
    try {
      // Try to parse as JSON
      const json = JSON.parse(text);
      const formattedHtml = formatJsonWithCollapse(json, 0);
      codeBlock.innerHTML = formattedHtml;
      
      // Add click handlers for collapse/expand
      codeBlock.querySelectorAll('.json-toggle').forEach(toggle => {
        toggle.addEventListener('click', (e) => {
          e.stopPropagation();
          const content = toggle.nextElementSibling;
          toggle.classList.toggle('collapsed');
          content.classList.toggle('collapsed');
        });
      });
    } catch (e) {
      // Not valid JSON, leave as-is
      console.log('Not valid JSON or already formatted:', e);
    }
  });
}

function formatJsonWithCollapse(obj, depth = 0) {
  const indent = '  '.repeat(depth);
  const nextIndent = '  '.repeat(depth + 1);
  
  if (obj === null) return '<span class="json-null">null</span>';
  if (typeof obj === 'boolean') return `<span class="json-boolean">${obj}</span>`;
  if (typeof obj === 'number') return `<span class="json-number">${obj}</span>`;
  if (typeof obj === 'string') return `<span class="json-string">"${escapeHtml(obj)}"</span>`;
  
  if (Array.isArray(obj)) {
    if (obj.length === 0) return '<span class="json-bracket">[]</span>';
    
    const preview = obj.length === 1 ? '1 item' : `${obj.length} items`;
    let html = `<span class="json-bracket">[</span>`;
    html += `<span class="json-toggle" title="Click to collapse/expand">${preview}</span>`;
    html += `<span class="json-collapsible">`;
    
    obj.forEach((item, i) => {
      html += `\n${nextIndent}`;
      html += formatJsonWithCollapse(item, depth + 1);
      if (i < obj.length - 1) html += '<span class="json-comma">,</span>';
    });
    
    html += `\n${indent}</span><span class="json-bracket">]</span>`;
    return html;
  }
  
  if (typeof obj === 'object') {
    const keys = Object.keys(obj);
    if (keys.length === 0) return '<span class="json-bracket">{}</span>';
    
    const preview = keys.length === 1 ? '1 key' : `${keys.length} keys`;
    let html = `<span class="json-bracket">{</span>`;
    html += `<span class="json-toggle" title="Click to collapse/expand">${preview}</span>`;
    html += `<span class="json-collapsible">`;
    
    keys.forEach((key, i) => {
      html += `\n${nextIndent}`;
      html += `<span class="json-key">"${escapeHtml(key)}"</span>: `;
      html += formatJsonWithCollapse(obj[key], depth + 1);
      if (i < keys.length - 1) html += '<span class="json-comma">,</span>';
    });
    
    html += `\n${indent}</span><span class="json-bracket">}</span>`;
    return html;
  }
  
  return String(obj);
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// Search within response
function initResponseSearch() {
  document.querySelectorAll('.body-content').forEach(bodyContent => {
    const searchBar = document.createElement('div');
    searchBar.className = 'response-search-bar';
    searchBar.innerHTML = `
      <input type="text" 
             class="response-search-input" 
             placeholder="Search in response... (Ctrl+F within section)"
             />
      <button class="response-search-btn">🔍</button>
      <button class="response-search-prev" title="Previous match (Shift+Enter)">◀</button>
      <button class="response-search-next" title="Next match (Enter)">▶</button>
      <button class="response-search-clear">✕</button>
      <span class="response-search-results"></span>
    `;
    
    const codeContainer = bodyContent.querySelector('pre');
    bodyContent.insertBefore(searchBar, codeContainer);
    
    const input = searchBar.querySelector('.response-search-input');
    const searchBtn = searchBar.querySelector('.response-search-btn');
    const prevBtn = searchBar.querySelector('.response-search-prev');
    const nextBtn = searchBar.querySelector('.response-search-next');
    const clearBtn = searchBar.querySelector('.response-search-clear');
    const resultsSpan = searchBar.querySelector('.response-search-results');
    const codeBlock = bodyContent.querySelector('pre code');
    
    let originalHtml = null;
    let currentMatchIndex = 0;
    let totalMatches = 0;
    
    function performSearch(scrollToFirst = true) {
      const query = input.value.trim();
      
      if (!query) {
        clearSearch();
        return;
      }
      
      if (originalHtml === null) {
        originalHtml = codeBlock.innerHTML;
      }
      
      const text = codeBlock.textContent;
      const regex = new RegExp(escapeRegex(query), 'gi');
      const matches = text.match(regex);
      
      if (matches) {
        totalMatches = matches.length;
        currentMatchIndex = 0;
        
        resultsSpan.textContent = `1 / ${totalMatches}`;
        resultsSpan.style.display = 'inline';
        
        // Show/hide navigation buttons
        prevBtn.style.display = totalMatches > 1 ? 'inline-block' : 'none';
        nextBtn.style.display = totalMatches > 1 ? 'inline-block' : 'none';
        
        // Highlight matches with data attributes
        let matchIndex = 0;
        const highlightRegex = new RegExp(`(${escapeRegex(query)})`, 'gi');
        const highlighted = text.replace(highlightRegex, (match) => {
          const index = matchIndex++;
          return `<mark class="search-highlight" data-match-index="${index}">${match}</mark>`;
        });
        codeBlock.textContent = '';
        codeBlock.innerHTML = escapeHtml(highlighted)
          .replace(/&lt;mark class="search-highlight" data-match-index="(\d+)"&gt;/g, '<mark class="search-highlight" data-match-index="$1">')
          .replace(/&lt;\/mark&gt;/g, '</mark>');
        
        if (scrollToFirst) {
          scrollToMatch(0);
        }
      } else {
        resultsSpan.textContent = 'No matches';
        resultsSpan.style.display = 'inline';
        prevBtn.style.display = 'none';
        nextBtn.style.display = 'none';
      }
    }
    
    function scrollToMatch(index) {
      // Remove current class from all highlights
      codeBlock.querySelectorAll('.search-highlight').forEach(mark => {
        mark.classList.remove('search-highlight-current');
      });
      
      // Add current class to target match
      const targetMatch = codeBlock.querySelector(`[data-match-index="${index}"]`);
      if (targetMatch) {
        targetMatch.classList.add('search-highlight-current');
        targetMatch.scrollIntoView({ behavior: 'smooth', block: 'center' });
        currentMatchIndex = index;
        resultsSpan.textContent = `${index + 1} / ${totalMatches}`;
      }
    }
    
    function nextMatch() {
      if (totalMatches > 0) {
        const nextIndex = (currentMatchIndex + 1) % totalMatches;
        scrollToMatch(nextIndex);
      }
    }
    
    function prevMatch() {
      if (totalMatches > 0) {
        const prevIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches;
        scrollToMatch(prevIndex);
      }
    }
    
    function clearSearch() {
      if (originalHtml !== null) {
        codeBlock.innerHTML = originalHtml;
        originalHtml = null;
      }
      input.value = '';
      resultsSpan.style.display = 'none';
      prevBtn.style.display = 'none';
      nextBtn.style.display = 'none';
      currentMatchIndex = 0;
      totalMatches = 0;
    }
    
    function escapeRegex(str) {
      return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
    
    searchBtn.addEventListener('click', () => performSearch(true));
    nextBtn.addEventListener('click', nextMatch);
    prevBtn.addEventListener('click', prevMatch);
    clearBtn.addEventListener('click', clearSearch);
    
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        if (e.shiftKey) {
          e.preventDefault();
          if (totalMatches > 0) {
            prevMatch();
          } else {
            performSearch(true);
          }
        } else {
          e.preventDefault();
          if (totalMatches > 0) {
            nextMatch();
          } else {
            performSearch(true);
          }
        }
      }
    });
    
    input.addEventListener('input', () => {
      if (input.value === '') clearSearch();
    });
  });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  // Wait a tick for the DOM to fully render
  setTimeout(() => {
    initJsonCollapsing();
    initResponseSearch();
    initBeKindRewind();
  }, 100);
});

// "Be Kind, Rewind" Easter Egg
function initBeKindRewind() {
  // Only on cassette detail pages
  const cassetteViewer = document.querySelector('.cassette-viewer');
  if (!cassetteViewer) return;
  
  // Add scroll listeners to individual response body containers
  document.querySelectorAll('.body-content pre').forEach(responseBody => {
    let easterEggShown = false;
    const scrollThreshold = 0.90; // 90% scrolled within the response
    
    responseBody.addEventListener('scroll', () => {
      const scrollHeight = responseBody.scrollHeight;
      const scrollTop = responseBody.scrollTop;
      const clientHeight = responseBody.clientHeight;
      
      // Check if response is long enough (more than 2 screen heights)
      if (scrollHeight < clientHeight * 2) return;
      
      const scrollPercentage = (scrollTop + clientHeight) / scrollHeight;
      
      if (scrollPercentage >= scrollThreshold && !easterEggShown) {
        easterEggShown = true;
        showBeKindRewind();
        
        // Reset after scrolling back up significantly
        const resetCheck = setInterval(() => {
          if (responseBody.scrollTop < scrollHeight * 0.3) {
            easterEggShown = false;
            clearInterval(resetCheck);
          }
        }, 1000);
      }
    });
  });
}

function showBeKindRewind() {
  const overlay = document.createElement('div');
  overlay.className = 'be-kind-rewind-overlay';
  overlay.innerHTML = `
    <div class="be-kind-rewind-message">
      <button class="rewind-close" onclick="this.closest('.be-kind-rewind-overlay').remove();" title="Close">✕</button>
      <div class="vcr-tape-icon">
        <div class="tape-body">
          <div class="tape-label">VCR</div>
          <div class="tape-window">
            <div class="tape-reel spinning"></div>
            <div class="tape-reel spinning"></div>
          </div>
        </div>
      </div>
      <div class="rewind-text">
        <div class="rewind-main">⏪ BE KIND, REWIND ⏪</div>
        <div class="rewind-sub">You've reached the end of this cassette</div>
      </div>
      <button class="rewind-button" onclick="this.closest('.be-kind-rewind-overlay').remove(); window.scrollTo({ top: 0, behavior: 'smooth' });">
        ⏮️ REWIND TO TOP
      </button>
    </div>
  `;
  
  document.body.appendChild(overlay);
  
  // Fade in animation
  setTimeout(() => overlay.classList.add('visible'), 10);
  
  // Click overlay background to dismiss
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) {
      overlay.classList.remove('visible');
      setTimeout(() => overlay.remove(), 500);
    }
  });
  
  // ESC key to dismiss
  const escHandler = (e) => {
    if (e.key === 'Escape') {
      overlay.classList.remove('visible');
      setTimeout(() => overlay.remove(), 500);
      document.removeEventListener('keydown', escHandler);
    }
  };
  document.addEventListener('keydown', escHandler);
  
  // Auto-remove after 8 seconds
  setTimeout(() => {
    if (overlay.parentElement) {
      overlay.classList.remove('visible');
      setTimeout(() => overlay.remove(), 500);
    }
  }, 8000);
}

console.log('🎬 VCR Inspector loaded - Press "/" to search');
