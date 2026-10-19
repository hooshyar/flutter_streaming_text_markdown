import { chromium } from 'playwright';
import { mkdirSync, rmSync } from 'node:fs';

rmSync('out', { recursive: true, force: true });
mkdirSync('out', { recursive: true });
const browser = await chromium.launch();
const url = 'https://hooshyar.github.io/flutter_streaming_text_markdown/';
const page = await browser.newPage({
  viewport: { width: 720, height: 1000 },
  deviceScaleFactor: 2,
  colorScheme: 'dark',
});
await page.goto(url, { waitUntil: 'networkidle' });
await page.waitForTimeout(8000);
await page.screenshot({ path: 'out/s00.png' });
await page.mouse.move(360, 500);
for (let i = 1; i <= 12; i++) {
  await page.mouse.wheel(0, 450);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `out/s${String(i).padStart(2, '0')}.png` });
}
await browser.close();
