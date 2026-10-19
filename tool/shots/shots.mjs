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
await page.mouse.move(360, 500);
for (let i = 1; i <= 12; i++) {
  await page.mouse.wheel(0, 450);
  await page.waitForTimeout(1500);
}
await page.waitForTimeout(2000);
await page.screenshot({ path: 'out/before.png' });
await page.mouse.click(618, 196);
for (const ms of [800, 1600, 2600, 4000, 7000]) {
  await page.waitForTimeout(ms === 800 ? 800 : ms - [800, 1600, 2600, 4000, 7000][[800, 1600, 2600, 4000, 7000].indexOf(ms) - 1]);
  await page.screenshot({ path: `out/stream-${ms}.png` });
}
for (let i = 1; i <= 3; i++) {
  await page.mouse.wheel(0, 450);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: `out/end-${i}.png` });
}
await browser.close();
