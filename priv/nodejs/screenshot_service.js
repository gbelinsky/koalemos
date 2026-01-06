/**
 * Server-side screenshot service using Puppeteer
 *
 * Captures pixel-perfect screenshots of HTML with full CSS support including:
 * - CSS gradients (linear, radial, conic)
 * - CSS transforms and filters
 * - Web fonts
 * - All modern CSS features
 *
 * This replaces client-side html-to-image which couldn't properly capture gradients.
 */

const puppeteer = require('puppeteer');

/**
 * Capture a screenshot of HTML content
 *
 * @param {string} html - Complete HTML document to render
 * @param {Object} options - Screenshot options
 * @param {Object} options.viewport - Viewport size {width: number, height: number}
 * @param {number} options.viewport.width - Viewport width in pixels (default: 1280)
 * @param {number} options.viewport.height - Viewport height in pixels (default: 720)
 * @param {boolean} options.fullPage - Capture full page or just viewport (default: false)
 * @param {Object} options.scrollPosition - Scroll position {x: number, y: number} (default: {x: 0, y: 0})
 * @param {number} options.quality - JPEG quality 0-100 (default: 70)
 * @returns {Promise<Object>} Object with {base64: string, width: number, height: number, mediaType: string}
 */
async function captureScreenshot(html, options = {}) {
  const viewport = options.viewport || { width: 1280, height: 720 };
  const fullPage = options.fullPage !== undefined ? options.fullPage : false;
  const scrollPosition = options.scrollPosition || { x: 0, y: 0 };
  const quality = options.quality !== undefined ? options.quality : 70;

  let browser = null;

  try {
    // Launch headless Chrome
    browser = await puppeteer.launch({
      headless: 'new',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--disable-gpu'
      ]
    });

    const page = await browser.newPage();

    // Set viewport size
    await page.setViewport({
      width: viewport.width,
      height: viewport.height,
      deviceScaleFactor: 1
    });

    // Set content and wait for it to be ready
    await page.setContent(html, {
      waitUntil: ['load', 'networkidle0']
    });

    // Scroll to the specified position to match preview iframe
    if (scrollPosition.x !== 0 || scrollPosition.y !== 0) {
      await page.evaluate((x, y) => {
        window.scrollTo(x, y);
      }, scrollPosition.x, scrollPosition.y);
    }

    // Wait a bit more for any animations or lazy-loaded styles
    // Using setTimeout instead of deprecated page.waitForTimeout
    await new Promise(resolve => setTimeout(resolve, 100));

    // Capture screenshot as base64 JPEG (smaller than PNG)
    const screenshotBuffer = await page.screenshot({
      type: 'jpeg',
      quality: quality,
      fullPage: fullPage,
      encoding: 'binary'
    });

    // Convert to base64
    const base64 = screenshotBuffer.toString('base64');

    // Get actual dimensions
    const dimensions = await page.evaluate(() => {
      return {
        width: document.documentElement.scrollWidth,
        height: document.documentElement.scrollHeight
      };
    });

    await browser.close();
    browser = null;

    return {
      base64: base64,
      width: dimensions.width,
      height: dimensions.height,
      mediaType: 'image/jpeg'
    };

  } catch (error) {
    // Ensure browser is closed on error
    if (browser) {
      await browser.close();
    }

    throw new Error(`Screenshot capture failed: ${error.message}`);
  }
}

module.exports = {
  captureScreenshot
};
