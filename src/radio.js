// filename: ./src/radio.js
// date: 06.10.2026
// generated with DeepSeek-V3 (https://www.deepseek.com)

const radioBtn = document.getElementById('radio-btn');

if (radioBtn) {
  let isPlaying = false;

  radioBtn.addEventListener('click', () => {
    isPlaying = !isPlaying;

    radioBtn.textContent = isPlaying ? '⏸' : '▶';
    radioBtn.setAttribute('aria-label', isPlaying ? 'Pause' : 'Play');
  });
}