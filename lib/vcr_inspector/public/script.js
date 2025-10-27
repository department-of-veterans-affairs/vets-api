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

console.log('🎬 VCR Inspector loaded - Press "/" to search');
